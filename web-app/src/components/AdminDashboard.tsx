import React, { useState, useEffect } from 'react';
import { 
  Users, 
  CreditCard, 
  MessageSquare, 
  Play,
  Square,
  RefreshCw,
  TrendingUp,
  ChevronRight,
  LogOut,
  Briefcase,
  Plus,
  FileText,
  LayoutGrid,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { PieChart, Pie, Cell, ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip } from 'recharts';

const COLORS = ['#FF8200', '#009A44', '#F43F5E', '#7C3AED'];

const AdminDashboard: React.FC<{ onLogout: () => void }> = ({ onLogout }) => {
  const [activeTab, setActiveTab] = useState<'overview' | 'users' | 'feedback' | 'jobs'>('overview');
  const [stats, setStats] = useState({
    totalUsers: 0,
    premiumUsers: 0,
    activeJobs: 0,
    pendingFeedback: 0
  });

  const [recentUsersList, setRecentUsersList] = useState<any[]>([]);
  
  // Job adding state
  const [jobType, setJobType] = useState('CDI');
  const [isBulkMode, setIsBulkMode] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [feedbacks, setFeedbacks] = useState<any[]>([]);
  const [unsubscriptions, setUnsubscriptions] = useState<any[]>([]);



  // Sample data for charts
  const userTypeData = [
    { name: 'Freemium', value: stats.totalUsers - stats.premiumUsers },
    { name: 'Premium', value: stats.premiumUsers },
  ];

  const [dailyActivity, setDailyActivity] = useState<any[]>([]);

  useEffect(() => {
    fetchStats();
    
    // Auto-refresh logs and status every 5 seconds
    const interval = setInterval(() => {
      fetchStats();
    }, 5000);
    
    return () => clearInterval(interval);
  }, [activeTab]);


  const fetchStats = async () => {
    try {
      // 1. Core user stats (these tables work fine)
      const { count: usersCount } = await supabase.from('profiles').select('id', { count: 'exact', head: true });
      const { count: premiumCount } = await supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('is_premium', true);
      const { count: jobsCount } = await supabase.from('jobs').select('id', { count: 'exact', head: true });
      
      setStats({
        totalUsers: usersCount || 0,
        premiumUsers: premiumCount || 0,
        activeJobs: jobsCount || 0,
        pendingFeedback: 0
      });

      // 2. Recent users
      const { data: userData } = await supabase
        .from('profiles')
        .select('id, full_name, is_premium, created_at')
        .order('created_at', { ascending: false })
        .limit(10);

      if (userData) {
        setRecentUsersList(userData.map(u => ({
          id: u.id,
          name: u.full_name || 'Anonyme',
          premium: u.is_premium,
          date: new Date(u.created_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
        })));
      }

      // 3. Feedbacks (without join - fetch user_id only, no profiles join)
      const { data: feedbackData, error: fbErr } = await supabase
        .from('feedbacks')
        .select('id, content, rating, created_at, user_id')
        .order('created_at', { ascending: false })
        .limit(10);
      
      if (!fbErr && feedbackData) {
        setStats(prev => ({ ...prev, pendingFeedback: feedbackData.length }));
        setFeedbacks(feedbackData.map((f: any) => ({
          user: 'Utilisateur',
          content: f.content,
          rating: f.rating,
          date: new Date(f.created_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }),
          type: 'feedback'
        })));
      }

      // 4. Unsubscriptions (without join)
      const { data: unsubData, error: unsubErr } = await supabase
        .from('unsubscriptions')
        .select('id, feedback, reason, created_at, user_id')
        .order('created_at', { ascending: false })
        .limit(10);
      
      if (!unsubErr && unsubData) {
        setUnsubscriptions(unsubData.map((u: any) => ({
          user: 'Utilisateur',
          content: u.feedback || 'Aucun commentaire',
          reason: u.reason || 'Non précisée',
          date: new Date(u.created_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }),
          type: 'unsub'
        })));
      }

      // 5. Daily activity chart data
      const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      const activity = Array.from({ length: 7 }, (_, i) => {
        const d = new Date();
        d.setDate(d.getDate() - (6 - i));
        const dayLabel = days[d.getDay()];
        const fbCount = (feedbackData || []).filter((f: any) => 
          new Date(f.created_at).toDateString() === d.toDateString()
        ).length;
        const unsubCount = (unsubData || []).filter((u: any) => 
          new Date(u.created_at).toDateString() === d.toDateString()
        ).length;
        return { name: dayLabel, count: fbCount + unsubCount };
      });
      setDailyActivity(activity);



    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };



  const handleAddSingleJob = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setIsLoading(true);
    setSuccessMessage('');
    setErrorMessage('');
    
    const formData = new FormData(e.currentTarget);
    const jobData = {
      title: formData.get('title'),
      company: formData.get('company'),
      location: formData.get('location'),
      type: jobType,
      description: formData.get('description'),
      image: formData.get('image'),
      source_url: formData.get('source_url'),
      created_at: new Date().toISOString()
    };

    try {
      const { error } = await supabase.from('jobs').insert([jobData]);
      if (error) throw error;
      setSuccessMessage('L\'offre d\'emploi a été ajoutée avec succès !');
      (e.target as HTMLFormElement).reset();
      fetchStats();
    } catch (err: any) {
      setErrorMessage(err.message || 'Erreur lors de l\'ajout de l\'offre');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddBulkJobs = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setIsLoading(true);
    setSuccessMessage('');
    setErrorMessage('');
    
    const formData = new FormData(e.currentTarget);
    const bulkText = formData.get('bulkText') as string;
    
    try {
      // Basic JSON parsing or multi-line parsing
      let jobs: any[] = [];
      
      try {
        jobs = JSON.parse(bulkText);
        if (!Array.isArray(jobs)) jobs = [jobs];
      } catch (jsonErr) {
        // Fallback: Line by line "Title - Company - Location - Type"
        const lines = bulkText.split('\n').filter(line => line.trim());
        jobs = lines.map(line => {
          const [title, company, location, type] = line.split('-').map(s => s.trim());
          return {
            title: title || 'Poste Inconnu',
            company: company || 'Entreprise Inconnue',
            location: location || 'Côte d\'Ivoire',
            type: type || 'CDI',
            created_at: new Date().toISOString()
          };
        });
      }

      if (jobs.length === 0) throw new Error('Aucune offre valide trouvée.');

      const { error } = await supabase.from('jobs').insert(jobs);
      if (error) throw error;
      
      setSuccessMessage(`${jobs.length} offres d'emploi ont été ajoutées !`);
      (e.target as HTMLFormElement).reset();
      fetchStats();
    } catch (err: any) {
      setErrorMessage(err.message || 'Erreur lors de l\'ajout massif');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex flex-col md:flex-row">
      {/* Sidebar / Topnav on mobile */}
      <aside className="w-full md:w-64 lg:w-72 bg-white border-b md:border-r border-slate-200 flex flex-col shrink-0">
        <div className="p-4 md:p-6 flex items-center justify-between gap-3 border-b border-slate-50">
          <div className="flex items-center gap-3">
            <div className="h-8 flex items-center justify-center">
               <img src="/logo.png" alt="Logo" className="h-full w-auto object-contain" />
            </div>
            <span className="font-heading font-bold text-lg">Admin<span className="text-secondary">Panel</span></span>
          </div>
        </div>
        
        <nav className="flex-row md:flex-col overflow-x-auto md:overflow-visible p-2 md:p-4 flex gap-2 md:gap-1 no-scrollbar shrink-0 border-b border-slate-100 md:border-none">
          <button 
            onClick={() => setActiveTab('overview')}
            className={`flex items-center gap-2 md:gap-3 px-3 md:px-4 py-2 md:py-3 rounded-lg text-xs md:text-sm font-medium transition-colors whitespace-nowrap shrink-0 ${activeTab === 'overview' ? 'bg-primary/10 text-primary' : 'text-slate-500 hover:bg-slate-50'}`}
          >
            <TrendingUp size={18} /> Vue d'ensemble
          </button>
          <button 
            onClick={() => setActiveTab('users')}
            className={`flex items-center gap-2 md:gap-3 px-3 md:px-4 py-2 md:py-3 rounded-lg text-xs md:text-sm font-medium transition-colors whitespace-nowrap shrink-0 ${activeTab === 'users' ? 'bg-primary/10 text-primary' : 'text-slate-500 hover:bg-slate-50'}`}
          >
            <Users size={18} /> Utilisateurs
          </button>

          <button 
            onClick={() => setActiveTab('feedback')}
            className={`flex items-center gap-2 md:gap-3 px-3 md:px-4 py-2 md:py-3 rounded-lg text-xs md:text-sm font-medium transition-colors whitespace-nowrap shrink-0 ${activeTab === 'feedback' ? 'bg-primary/10 text-primary' : 'text-slate-500 hover:bg-slate-50'}`}
          >
            <MessageSquare size={18} /> Feedbacks & Désab.
          </button>
          <button 
            onClick={() => setActiveTab('jobs')}
            className={`flex items-center gap-2 md:gap-3 px-3 md:px-4 py-2 md:py-3 rounded-lg text-xs md:text-sm font-medium transition-colors whitespace-nowrap shrink-0 ${activeTab === 'jobs' ? 'bg-primary/10 text-primary' : 'text-slate-500 hover:bg-slate-50'}`}
          >
            <Plus size={18} /> Ajouter Offres
          </button>
          <button 
             onClick={onLogout}
             className="md:hidden flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-medium text-red-500 hover:bg-red-50 transition-colors whitespace-nowrap shrink-0"
          >
             <LogOut size={18} /> Déconnexion
          </button>
        </nav>

        <div className="hidden md:block p-4 border-t border-slate-100 mt-auto">
          <button onClick={onLogout} className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium text-red-500 hover:bg-red-50 transition-colors">
            <LogOut size={18} /> Déconnexion
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto overflow-x-hidden p-4 md:p-8 w-full">
        <header className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6 md:mb-10">
          <div>
            <h1 className="text-3xl text-slate-900 font-heading">
              {activeTab === 'overview' && 'Tableau de Bord'}
              {activeTab === 'users' && 'Gestion Utilisateurs'}

              {activeTab === 'feedback' && 'Retours Utilisateurs'}
              {activeTab === 'jobs' && 'Gestion des Offres'}
            </h1>
            <p className="text-slate-500 mt-1">Gérez Djorssi-Match et surveillez votre croissance.</p>
          </div>
          <div className="flex items-center gap-4">
             <div className="text-right">
                <p className="text-sm font-bold text-slate-900">Admin User</p>
                <p className="text-xs text-slate-500">Super Admin</p>
             </div>
             <div className="w-10 h-10 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center text-primary font-bold">
               AD
             </div>
          </div>
        </header>

        {activeTab === 'overview' && (
          <div className="space-y-8">
            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <StatCard title="Utilisateurs" value={stats.totalUsers.toLocaleString()} icon={<Users />} color="bg-primary" trend="+12% cette semaine" />
              <StatCard title="Abonnés Premium" value={stats.premiumUsers.toLocaleString()} icon={<CreditCard />} color="bg-secondary" trend="+5% cette semaine" />
              <StatCard title="Offres Actives" value={stats.activeJobs.toLocaleString()} icon={<Briefcase />} color="bg-secondary" trend="+24 ajoutées" />
              <StatCard title="Messages" value={stats.pendingFeedback.toLocaleString()} icon={<MessageSquare />} color="bg-primary" trend="3 non lus" />
            </div>

            <div className="grid lg:grid-cols-3 gap-8">
              {/* Distribution Chart */}
              <div className="lg:col-span-1 bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                 <h3 className="text-lg mb-6">Répartition Premium</h3>
                 <div className="h-64">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={userTypeData}
                          innerRadius={60}
                          outerRadius={80}
                          paddingAngle={5}
                          dataKey="value"
                        >
                          {userTypeData.map((_, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                          ))}
                        </Pie>
                        <Tooltip />
                      </PieChart>
                    </ResponsiveContainer>
                 </div>
                 <div className="flex justify-center gap-6 mt-4">
                    <div className="flex items-center gap-2 text-xs font-medium text-slate-500">
                      <div className="w-3 h-3 rounded-full bg-secondary" /> Freemium
                    </div>
                    <div className="flex items-center gap-2 text-xs font-medium text-slate-500">
                      <div className="w-3 h-3 rounded-full bg-cta" /> Premium
                    </div>
                 </div>
              </div>

              {/* Bar Chart */}
              <div className="lg:col-span-2 bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                 <h3 className="text-lg mb-6">Activité Feedback (7 derniers jours)</h3>
                 <div className="h-64 text-xs">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={dailyActivity}>
                        <XAxis dataKey="name" />
                        <YAxis />
                        <Tooltip />
                        <Bar dataKey="count" fill="#FF8200" radius={[4, 4, 0, 0]} />
                      </BarChart>
                    </ResponsiveContainer>
                 </div>
              </div>
            </div>
            
            {/* Recent Users Table */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden w-full">
               <div className="p-4 md:p-6 border-b border-slate-100 flex justify-between items-center">
                  <h3 className="text-lg">Derniers Utilisateurs</h3>
                  <button onClick={() => setActiveTab('users')} className="text-primary text-sm font-semibold flex items-center gap-1 hover:underline">
                    Voir tout <ChevronRight size={16} />
                  </button>
               </div>
               <div className="overflow-x-auto">
                 <table className="w-full text-left whitespace-nowrap">
                  <thead className="bg-slate-50 text-slate-500 text-xs font-semibold uppercase tracking-wider">
                     <tr>
                        <th className="px-6 py-4">Nom</th>
                        <th className="px-6 py-4">Status</th>
                        <th className="px-6 py-4">Date Inscription</th>
                        <th className="px-6 py-4 text-right">Actions</th>
                     </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                     {recentUsersList.length > 0 ? recentUsersList.slice(0, 5).map(user => (
                       <tr key={user.id} className="hover:bg-slate-50/50 transition-colors">
                          <td className="px-6 py-4 font-medium text-slate-900">{user.name}</td>
                          <td className="px-6 py-4">
                             <span className={`px-2 py-1 rounded-full text-[10px] font-bold uppercase ${user.premium ? 'bg-cta/10 text-cta' : 'bg-slate-100 text-slate-500'}`}>
                                {user.premium ? 'Premium' : 'Free'}
                             </span>
                          </td>
                          <td className="px-6 py-4 text-sm text-slate-500">{user.date}</td>
                          <td className="px-6 py-4 text-right">
                             <button className="text-slate-400 hover:text-primary transition-colors">
                                <ChevronRight size={18} />
                             </button>
                          </td>
                       </tr>
                     )) : (
                        <tr>
                           <td colSpan={4} className="px-6 py-8 text-center text-slate-400 italic">Aucun utilisateur récent</td>
                        </tr>
                     )}
                  </tbody>
               </table>
               </div>
            </div>
          </div>
        )}

        {activeTab === 'users' && (
          <div className="space-y-6">
            <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
              <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-6">
                <h3 className="text-xl font-bold">Tous les Utilisateurs</h3>
                <div className="relative w-full md:w-64">
                   <input 
                     type="text" 
                     placeholder="Rechercher un utilisateur..." 
                     className="w-full pl-4 pr-10 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                   />
                </div>
              </div>
              
              <div className="overflow-x-auto">
                <table className="w-full text-left whitespace-nowrap">
                  <thead className="bg-slate-50 text-slate-500 text-xs font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Utilisateur</th>
                      <th className="px-6 py-4">Email</th>
                      <th className="px-6 py-4">Status</th>
                      <th className="px-6 py-4">ID</th>
                      <th className="px-6 py-4 font-medium">Inscription</th>
                      <th className="px-6 py-4 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {recentUsersList.length > 0 ? recentUsersList.map(user => (
                      <tr key={user.id} className="hover:bg-slate-50/50 transition-colors">
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-xs">
                              {user.name.charAt(0)}
                            </div>
                            <span className="font-medium text-slate-900">{user.name}</span>
                          </div>
                        </td>
                        <td className="px-6 py-4 text-sm text-slate-500">Profil #{user.id.substring(0, 5)}</td>
                        <td className="px-6 py-4">
                          <span className={`px-2 py-1 rounded-full text-[10px] font-bold uppercase ${user.premium ? 'bg-cta/10 text-cta' : 'bg-slate-100 text-slate-500'}`}>
                            {user.premium ? 'Premium' : 'Free'}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-xs text-slate-400 font-mono">{user.id.substring(0, 8)}...</td>
                        <td className="px-6 py-4 text-sm text-slate-500">{user.date}</td>
                        <td className="px-6 py-4 text-right">
                          <button className="text-slate-400 hover:text-primary transition-colors">
                            <ChevronRight size={18} />
                          </button>
                        </td>
                      </tr>
                    )) : (
                      <tr>
                        <td colSpan={6} className="px-6 py-10 text-center text-slate-400 italic">
                          Chargement des utilisateurs ou aucun utilisateur trouvé...
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}



        {activeTab === 'feedback' && (
          <div className="grid grid-cols-1 gap-6">
            <h3 className="text-xl mb-4 text-slate-900 font-bold">Raisons des Désabonnements</h3>
            <div className="grid md:grid-cols-2 gap-6">
               {unsubscriptions.length > 0 ? unsubscriptions.map((unsub, idx) => (
                 <FeedbackCard 
                   key={`unsub-${idx}`}
                   type="unsub" 
                   user={unsub.user} 
                   date={unsub.date} 
                   content={unsub.content} 
                   reason={unsub.reason}
                 />
               )) : (
                 <p className="text-slate-400 italic col-span-2">Aucun désabonnement enregistré.</p>
               )}
            </div>
            
            <h3 className="text-xl mt-8 mb-4 text-slate-900 font-bold">Feedbacks Récents</h3>
            <div className="grid md:grid-cols-3 gap-6">
               {feedbacks.length > 0 ? feedbacks.map((fb, idx) => (
                 <FeedbackCard 
                   key={`fb-${idx}`}
                   type="feedback" 
                   user={fb.user} 
                   date={fb.date} 
                   content={fb.content} 
                   rating={fb.rating}
                 />
               )) : (
                 <p className="text-slate-400 italic col-span-3">Aucun feedback enregistré.</p>
               )}
            </div>
          </div>
        )}

        {activeTab === 'jobs' && (
          <div className="max-w-4xl space-y-8 animate-in fade-in slide-in-from-bottom-2 duration-500">
            <div className="flex gap-4 p-1 bg-slate-100 rounded-xl w-fit">
              <button 
                onClick={() => setIsBulkMode(false)}
                className={`flex items-center gap-2 px-6 py-2 rounded-lg text-sm font-bold transition-all ${!isBulkMode ? 'bg-white shadow-sm' : 'text-slate-500 hover:bg-white/50'}`}
              >
                <FileText size={18} /> Offre Unique
              </button>
              <button 
                onClick={() => setIsBulkMode(true)}
                className={`flex items-center gap-2 px-6 py-2 rounded-lg text-sm font-bold transition-all ${isBulkMode ? 'bg-white shadow-sm' : 'text-slate-500 hover:bg-white/50'}`}
              >
                <LayoutGrid size={18} /> Ajout Massif
              </button>
            </div>

            {successMessage && (
              <div className="bg-green-50 border-2 border-green-500/20 p-4 rounded-xl flex items-center gap-3 text-green-700 font-bold">
                <CheckCircle2 className="shrink-0" /> {successMessage}
              </div>
            )}

            {errorMessage && (
              <div className="bg-red-50 border-2 border-red-500/20 p-4 rounded-xl flex items-center gap-3 text-red-700 font-bold">
                <AlertCircle className="shrink-0" /> {errorMessage}
              </div>
            )}

            {!isBulkMode ? (
              <div className="bg-white p-6 md:p-8 rounded-2xl border border-slate-200 shadow-sm">
                <form onSubmit={handleAddSingleJob} className="space-y-6">
                  <div className="grid md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-sm font-black uppercase tracking-tight text-slate-500">Intitulé du Poste</label>
                      <input name="title" required placeholder="Ex: Développeur React Junior" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
                    </div>
                    <div className="space-y-2">
                      <label className="text-sm font-black uppercase tracking-tight text-slate-500">Entreprise</label>
                      <input name="company" required placeholder="Ex: Orange CI" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
                    </div>
                  </div>

                  <div className="grid md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-sm font-black uppercase tracking-tight text-slate-500">Lieu</label>
                      <input name="location" required placeholder="Ex: Abidjan, Plateau" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
                    </div>
                    <div className="space-y-2">
                      <label className="text-sm font-black uppercase tracking-tight text-slate-500">Type de Contrat</label>
                      <select 
                        value={jobType}
                        onChange={(e) => setJobType(e.target.value)}
                        className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium"
                      >
                        <option>CDI</option>
                        <option>CDD</option>
                        <option>Stage</option>
                        <option>Freelance</option>
                        <option>Intérim</option>
                      </select>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <label className="text-sm font-black uppercase tracking-tight text-slate-500">URL Image (Optional)</label>
                    <input name="image" placeholder="Lien vers une image ou logo" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
                  </div>

                  <div className="space-y-2">
                    <label className="text-sm font-black uppercase tracking-tight text-slate-500">URL de l'offre source (Optional)</label>
                    <input name="source_url" placeholder="https://..." className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
                  </div>

                  <div className="space-y-2">
                    <label className="text-sm font-black uppercase tracking-tight text-slate-500">Description</label>
                    <textarea name="description" rows={4} placeholder="Détails du poste..." className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium resize-none"></textarea>
                  </div>

                  <button 
                    disabled={isLoading}
                    className="w-full bg-primary text-white font-black py-4 rounded-xl border-b-4 border-slate-900 active:border-b-0 active:translate-y-1 transition-all flex items-center justify-center gap-2 uppercase tracking-widest disabled:opacity-50"
                  >
                    {isLoading ? <RefreshCw className="animate-spin" /> : <Plus />} Ajouter l'offre
                  </button>
                </form>
              </div>
            ) : (
              <div className="bg-white p-6 md:p-8 rounded-2xl border border-slate-200 shadow-sm space-y-6">
                <div className="bg-primary/5 p-4 rounded-xl border-l-4 border-primary">
                  <p className="text-sm font-bold text-slate-800">Format accepté :</p>
                  <p className="text-xs text-slate-600 mt-1">Collez un tableau JSON d'offres OU une liste formatée ainsi : <br /><strong>Titre - Entreprise - Lieu - Type</strong> (une offre par ligne)</p>
                </div>

                <form onSubmit={handleAddBulkJobs} className="space-y-6">
                  <div className="space-y-2">
                    <label className="text-sm font-black uppercase tracking-tight text-slate-500">Données Massives</label>
                    <textarea 
                      name="bulkText"
                      required
                      rows={12} 
                      placeholder='Ex JSON: [{"title": "Dev", "company": "..."}]&#10;Ex Liste: Dev Web - Tech SA - Plateau - CDI' 
                      className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-mono text-sm resize-none"
                    ></textarea>
                  </div>

                  <button 
                    disabled={isLoading}
                    className="w-full bg-secondary text-white font-black py-4 rounded-xl border-b-4 border-slate-900 active:border-b-0 active:translate-y-1 transition-all flex items-center justify-center gap-2 uppercase tracking-widest disabled:opacity-50"
                  >
                    {isLoading ? <RefreshCw className="animate-spin" /> : <LayoutGrid />} Importer les offres
                  </button>
                </form>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
};

const StatCard = ({ title, value, icon, color, trend }: any) => (
  <div className="bg-white p-4 md:p-6 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between hover:border-primary/30 transition-colors">
    <div className="flex justify-between items-start mb-4">
      <div className={`w-10 h-10 md:w-12 md:h-12 rounded-xl flex items-center justify-center text-white ${color} shadow-lg shadow-black/10`}>
        {React.cloneElement(icon, { size: 20, className: "md:w-6 md:h-6" })}
      </div>
      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-tighter">Live Stats</span>
    </div>
    <div>
      <p className="text-slate-500 text-xs md:text-sm font-medium">{title}</p>
      <div className="flex items-baseline gap-2 flex-wrap">
         <h4 className="text-2xl md:text-3xl font-heading font-bold text-slate-900">{value}</h4>
         <span className="text-[10px] font-bold text-cta whitespace-nowrap">{trend}</span>
      </div>
    </div>
  </div>
);

const FeedbackCard = ({ type, user, date, content, reason, rating }: any) => (
  <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
    <div className="flex justify-between items-start mb-4">
       <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-400 text-xs font-bold">
            {user.charAt(0)}
          </div>
          <div>
            <p className="text-sm font-bold text-slate-900">{user}</p>
            <p className="text-xs text-slate-400">{date}</p>
          </div>
       </div>
       <span className={`text-[10px] font-bold px-2 py-0.5 rounded uppercase ${type === 'unsub' ? 'bg-red-50 text-red-500' : 'bg-secondary/10 text-secondary'}`}>
         {type === 'unsub' ? 'Désabonné' : 'Feedback'}
       </span>
    </div>
    <p className="text-sm text-slate-600 mb-4 italic">"{content}"</p>
    {reason && (
      <div className="flex items-center gap-2 text-xs font-semibold text-slate-500">
         <span className="bg-slate-100 px-2 py-1 rounded">Raison: {reason}</span>
      </div>
    )}
    {rating && (
       <div className="flex gap-1">
          {[1, 2, 3, 4, 5].map(i => (
             <div key={i} className={`w-2 h-2 rounded-full ${i <= rating ? 'bg-orange-400' : 'bg-slate-200'}`} />
          ))}
       </div>
    )}
  </div>
);

export default AdminDashboard;
