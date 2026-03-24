import React, { useState, useEffect } from 'react';
import { 
  Users, 
  LogOut,
  Briefcase,
  Plus,
  TrendingUp,
  MessageSquare,
  Settings
} from 'lucide-react';
import { supabase } from '../lib/supabase';

import UserEditModal from './admin/UserEditModal';
import JobEditModal from './admin/JobEditModal';
import OverviewTab from './admin/OverviewTab';
import UsersTab from './admin/UsersTab';
import FeedbackTab from './admin/FeedbackTab';
import AddJobTab from './admin/AddJobTab';
import JobsTab from './admin/JobsTab';
import SettingsTab from './admin/SettingsTab';

const cleanPhone = (phone: any): string => {
  if (!phone) return "";
  const cleaned = String(phone).replace(/[^0-9]/g, '');
  if (cleaned.length === 10) {
    return `225${cleaned}`;
  } else if (cleaned.length === 8) {
    return `22507${cleaned}`;
  }
  return cleaned;
};

const COLORS = ['#FF8200', '#009A44', '#F43F5E', '#7C3AED'];

const AdminDashboard: React.FC<{ onLogout: () => void }> = ({ onLogout }) => {
  const [activeTab, setActiveTab] = useState<'overview' | 'users' | 'feedback' | 'add-jobs' | 'all-jobs' | 'settings'>('overview');
  const [stats, setStats] = useState({
    totalUsers: 0,
    premiumUsers: 0,
    activeJobs: 0,
    pendingFeedback: 0
  });

  const [recentUsersList, setRecentUsersList] = useState<any[]>([]);
  
  // Job adding state
  const [isBulkMode, setIsBulkMode] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [feedbacks, setFeedbacks] = useState<any[]>([]);
  const [unsubscriptions, setUnsubscriptions] = useState<any[]>([]);
  const [passwordSuccess, setPasswordSuccess] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'premium' | 'free'>('all');
  const [editingUser, setEditingUser] = useState<any | null>(null);
  const [isResettingPassword, setIsResettingPassword] = useState(false);
  const [jobsList, setJobsList] = useState<any[]>([]);
  const [jobsSearch, setJobsSearch] = useState('');
  const [editingJob, setEditingJob] = useState<any | null>(null);

  const [dailyActivity, setDailyActivity] = useState<any[]>([]);

  const userTypeData = [
    { name: 'Freemium', value: stats.totalUsers - stats.premiumUsers },
    { name: 'Premium', value: stats.premiumUsers },
  ];

  useEffect(() => {
    fetchStats();
    fetchJobs();
    
    // Auto-refresh logs and status every 5 seconds
    const interval = setInterval(() => {
      fetchStats();
    }, 5000);
    
    return () => clearInterval(interval);
  }, [activeTab]);

  const fetchStats = async () => {
    try {
      const { count: usersCount } = await supabase.from('profiles').select('id', { count: 'exact', head: true });
      const { count: premiumCount } = await supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('is_premium', true);
      const { count: jobsCount } = await supabase.from('jobs').select('id', { count: 'exact', head: true });
      
      setStats({
        totalUsers: usersCount || 0,
        premiumUsers: premiumCount || 0,
        activeJobs: jobsCount || 0,
        pendingFeedback: 0
      });

      const { data: userData } = await supabase
        .from('profiles')
        .select('id, full_name, is_premium, created_at, phone_number, skills')
        .order('created_at', { ascending: false })
        .limit(100);

      if (userData) {
        setRecentUsersList(userData.map(u => ({
          id: u.id,
          name: u.full_name || 'Anonyme',
          premium: u.is_premium,
          date: new Date(u.created_at).toLocaleDateString(),
          phone: u.phone_number || '-',
          sector: Array.isArray(u.skills) ? u.skills.join(', ') : (u.skills || '-')
        })));
      }

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
    const item = {
      title: formData.get('title'),
      company_name: formData.get('company_name'),
      lieu: formData.get('lieu'),
      niveau: formData.get('niveau'),
      summary: formData.get('summary'),
      urls: formData.get('urls'),
      email: formData.get('email'),
      deadline: formData.get('deadline'),
      contact: formData.get('contact'),
      objet: formData.get('objet'),
      lettre_motivation: formData.get('lettre_motivation'),
      salary_range: formData.get('salary_range'),
      tags: formData.get('tags') ? (formData.get('tags') as string).split(',').map(s => s.trim()) : []
    };

    const jobData = {
      job_title: item.title || "Sans titre",
      company_name: item.company_name || "Non précisé",
      description: item.summary || "",
      deadline: item.deadline || null,
      required_level: item.niveau || null,
      location: item.lieu || "Côte d'Ivoire",
      source_url: item.urls || `manual_${Date.now()}`,
      is_ai_verified: true,
      tags: item.tags,
      contact_email: item.email || null,
      whatsapp_number: cleanPhone(item.contact as string),
      application_instructions: item.objet || null,
      application_link: item.urls || null,
      requires_cover_letter: !!item.lettre_motivation && String(item.lettre_motivation).toUpperCase() !== "NON",
      cover_letter_instructions: item.lettre_motivation || null,
      salary_range: item.salary_range || null,
      created_at: new Date().toISOString(),
      raw_data: item
    };

    try {
      const { error } = await supabase.from('jobs').insert([jobData]);
      if (error) throw error;
      setSuccessMessage('L\'offre d\'emploi a été ajoutée avec succès !');
      (e.target as HTMLFormElement).reset();
      fetchStats();
      fetchJobs(); 
    } catch (err: any) {
      setErrorMessage(err.message || 'Erreur lors de l\'ajout de l\'offre');
    } finally {
      setIsLoading(false);
    }
  };

  const fetchJobs = async () => {
    try {
      const { data, error } = await supabase
        .from('jobs')
        .select('*')
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      setJobsList(data || []);
    } catch (err: any) {
      console.error("Error fetching jobs:", err);
    }
  };

  const handleDeleteJob = async (jobId: string) => {
    if (!window.confirm("Voulez-vous vraiment supprimer cette offre d'emploi ?")) return;
    setIsLoading(true);
    try {
      const { error } = await supabase.from('jobs').delete().eq('id', jobId);
      if (error) throw error;
      setSuccessMessage("Offre d'emploi supprimée !");
      setJobsList(prev => prev.filter(j => j.id !== jobId));
    } catch (err: any) {
      setErrorMessage(err.message || "Erreur de suppression");
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpdateJob = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingJob) return;
    setIsLoading(true);
    setErrorMessage('');
    
    try {
      const skillsArray = typeof editingJob.tags === 'string' 
        ? editingJob.tags.split(',').map((s: string) => s.trim()).filter((s: string) => s !== '')
        : editingJob.tags;

      const { error } = await supabase
        .from('jobs')
        .update({
          job_title: editingJob.job_title,
          company_name: editingJob.company_name,
          location: editingJob.location,
          description: editingJob.description,
          tags: skillsArray,
          deadline: editingJob.deadline,
          salary_range: editingJob.salary_range,
          application_link: editingJob.application_link,
          source_url: editingJob.source_url || editingJob.application_link,
          contact_email: editingJob.contact_email,
          whatsapp_number: cleanPhone(editingJob.whatsapp_number),
          application_instructions: editingJob.application_instructions,
          required_level: editingJob.required_level
        })
        .eq('id', editingJob.id);

      if (error) throw error;
      setEditingJob(null);
      fetchJobs();
    } catch (err: any) {
      setErrorMessage(err.message || "Erreur lors de la mise à jour");
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
      let jobsToAdd: any[] = [];
      try {
        const parsed = JSON.parse(bulkText);
        jobsToAdd = Array.isArray(parsed) ? parsed : [parsed];
      } catch (err) {
        const lines = bulkText.split('\n').filter(l => l.trim().includes('-'));
        jobsToAdd = lines.map(line => {
          const [title, company] = line.split('-').map(s => s.trim());
          return { title, company_name: company };
        });
      }

      const formattedJobs = jobsToAdd.map(item => ({
        job_title: item.title || item.job_title || "Sans titre",
        company_name: item.company_name || "Non précisé",
        location: item.lieu || item.location || "Côte d'Ivoire",
        description: item.summary || item.description || "",
        tags: Array.isArray(item.tags) ? item.tags : (typeof item.tags === 'string' ? item.tags.split(',').map((s: any) => s.trim()) : []),
        deadline: item.deadline || null,
        whatsapp_number: cleanPhone(item.contact || item.whatsapp_number),
        contact_email: item.email || item.contact_email || null,
        application_instructions: item.objet || item.application_instructions || null,
        required_level: item.niveau || item.required_level || null,
        salary_range: item.salary_range || null,
        is_ai_verified: true,
        source_url: item.urls || `bulk_${Date.now()}`,
        created_at: new Date().toISOString(),
        raw_data: item
      }));

      const { error } = await supabase.from('jobs').insert(formattedJobs);
      if (error) throw error;

      setSuccessMessage(`${formattedJobs.length} offres ajoutées avec succès !`);
      (e.target as HTMLFormElement).reset();
      fetchJobs();
    } catch (err: any) {
      setErrorMessage("Erreur d'importation: " + err.message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const content = event.target?.result as string;
      const textArea = document.getElementById('bulkText') as HTMLTextAreaElement;
      if (textArea) {
        textArea.value = content;
      }
    };
    reader.readAsText(file);
  };

  const handleTogglePremium = async (userId: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ is_premium: !currentStatus })
        .eq('id', userId);

      if (error) throw error;
      setRecentUsersList(prev => prev.map(u => u.id === userId ? { ...u, premium: !currentStatus } : u));
    } catch (err) {
      console.error("Error toggling premium:", err);
    }
  };

  const handleUpdateUserProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingUser) return;
    setIsLoading(true);
    try {
      const skillsArray = typeof editingUser.sector === 'string' 
        ? editingUser.sector.split(',').map((s: string) => s.trim()).filter((s: string) => s !== '')
        : editingUser.sector;

      const { error } = await supabase
        .from('profiles')
        .update({
          full_name: editingUser.name,
          phone_number: editingUser.phone,
          is_premium: editingUser.premium,
          skills: skillsArray
        })
        .eq('id', editingUser.id);

      if (error) throw error;
      setRecentUsersList(prev => prev.map(u => u.id === editingUser.id ? editingUser : u));
      setEditingUser(null);
    } catch (err) {
      console.error("Error updating profile:", err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDeleteProfile = async (userId: string) => {
    if (!window.confirm("Action irréversible : Supprimer cet utilisateur ?")) return;
    try {
      const { error } = await supabase.from('profiles').delete().eq('id', userId);
      if (error) throw error;
      setRecentUsersList(prev => prev.filter(u => u.id !== userId));
    } catch (err) {
      console.error("Error deleting profile:", err);
    }
  };

  const handleSendPasswordReset = async () => {
    if (!editingUser) return;
    setIsResettingPassword(true);
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(editingUser.id);
      const email = userData?.user?.email;
      if (!email) throw new Error("Email non trouvé");
      await supabase.auth.resetPasswordForEmail(email, { redirectTo: window.location.origin + '/admin' });
      alert("Email envoyé à " + email);
    } catch (err: any) {
      alert("Erreur: " + err.message);
    } finally {
      setIsResettingPassword(false);
    }
  };

  const handleUpdatePassword = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setIsLoading(true);
    setPasswordError('');
    setPasswordSuccess('');
    
    const formData = new FormData(e.currentTarget);
    const newPassword = formData.get('newPassword') as string;
    const confirmPassword = formData.get('confirmPassword') as string;

    if (newPassword !== confirmPassword) {
      setPasswordError("Les mots de passe ne correspondent pas.");
      setIsLoading(false);
      return;
    }

    try {
      const { error } = await supabase.auth.updateUser({ password: newPassword });
      if (error) throw error;
      setPasswordSuccess("Votre mot de passe a été mis à jour avec succès.");
      e.currentTarget.reset();
    } catch (error: any) {
      setPasswordError(error.message || "Une erreur est survenue.");
    } finally {
      setIsLoading(false);
    }
  };

  const navItems = [
    { id: 'overview', label: 'Vue d\'ensemble', icon: <TrendingUp size={20} /> },
    { id: 'users', label: 'Utilisateurs', icon: <Users size={20} /> },
    { id: 'all-jobs', label: 'Base des Offres', icon: <Briefcase size={20} /> },
    { id: 'add-jobs', label: 'Ajout d\'Annonces', icon: <Plus size={20} /> },
    { id: 'feedback', label: 'Feedback', icon: <MessageSquare size={20} /> },
    { id: 'settings', label: 'Sécurité', icon: <Settings size={20} /> },
  ];

  return (
    <div className="flex h-screen bg-slate-50 font-sans text-slate-900 overflow-hidden">
      {/* Sidebar navigation remained as is for structure */}
      <aside className="w-72 bg-white border-r border-slate-200 flex flex-col shadow-sm z-20 overflow-y-auto">
        <div className="p-8">
           <div className="flex items-center gap-3 mb-10">
              <div className="w-10 h-10 bg-primary rounded-xl flex items-center justify-center text-white font-black text-xl shadow-lg shadow-primary/20">D</div>
              <h1 className="text-xl font-black tracking-tighter">DJORSSI <span className="text-primary italic">ADMIN</span></h1>
           </div>
           
           <nav className="space-y-1">
             {navItems.map(item => (
               <button
                 key={item.id}
                 onClick={() => setActiveTab(item.id as any)}
                 className={`w-full flex items-center gap-4 px-4 py-3.5 rounded-xl text-sm font-bold transition-all group ${
                   activeTab === item.id 
                    ? 'bg-primary text-white shadow-md shadow-primary/20 scale-[1.02]' 
                    : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900'
                 }`}
               >
                 <span className={`${activeTab === item.id ? 'text-white' : 'text-slate-400 group-hover:text-primary transition-colors'}`}>
                    {item.icon}
                 </span>
                 {item.label}
                 {activeTab === item.id && <div className="ml-auto w-1.5 h-1.5 rounded-full bg-white animate-pulse" />}
               </button>
             ))}
           </nav>
        </div>

        <div className="mt-auto p-8 pt-0">
           <button 
             type="button"
             onClick={onLogout}
             className="w-full flex items-center gap-4 px-4 py-3.5 rounded-xl text-sm font-bold text-red-500 hover:bg-red-50 transition-all group"
           >
             <LogOut size={20} className="group-hover:rotate-12 transition-transform" />
             Déconnexion
           </button>
        </div>
      </aside>

      <main className="flex-1 overflow-y-auto p-4 md:p-10 relative custom-scrollbar">
        <header className="flex justify-between items-center mb-10">
           <div>
              <h2 className="text-3xl font-black text-slate-900 uppercase tracking-tighter">
                {navItems.find(i => i.id === activeTab)?.label}
              </h2>
              <p className="text-slate-500 text-sm font-medium mt-1">Gérez votre plateforme avec précision et efficacité.</p>
           </div>
           
           <div className="flex items-center gap-4 bg-white p-2 pr-6 rounded-2xl border border-slate-200 shadow-sm">
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
          <OverviewTab 
            stats={stats} 
            userTypeData={userTypeData} 
            dailyActivity={dailyActivity} 
            recentUsersList={recentUsersList} 
            COLORS={COLORS} 
            setActiveTab={setActiveTab} 
          />
        )}

        {activeTab === 'users' && (
          <UsersTab 
            stats={stats}
            searchTerm={searchTerm}
            setSearchTerm={setSearchTerm}
            statusFilter={statusFilter}
            setStatusFilter={setStatusFilter}
            recentUsersList={recentUsersList}
            handleTogglePremium={handleTogglePremium}
            handleDeleteProfile={handleDeleteProfile}
            setEditingUser={setEditingUser}
          />
        )}

        {activeTab === 'feedback' && (
          <FeedbackTab feedbacks={feedbacks} unsubscriptions={unsubscriptions} />
        )}

        {activeTab === 'add-jobs' && (
          <AddJobTab 
            isBulkMode={isBulkMode}
            setIsBulkMode={setIsBulkMode}
            successMessage={successMessage}
            errorMessage={errorMessage}
            isLoading={isLoading}
            handleAddSingleJob={handleAddSingleJob}
            handleAddBulkJobs={handleAddBulkJobs}
            handleFileUpload={handleFileUpload}
          />
        )}

        {activeTab === 'all-jobs' && (
          <JobsTab 
            jobsList={jobsList}
            jobsSearch={jobsSearch}
            setJobsSearch={setJobsSearch}
            setEditingJob={setEditingJob}
            handleDeleteJob={handleDeleteJob}
          />
        )}

        {activeTab === 'settings' && (
          <SettingsTab 
            handleUpdatePassword={handleUpdatePassword}
            passwordError={passwordError}
            passwordSuccess={passwordSuccess}
            isLoading={isLoading}
            onLogout={onLogout}
          />
        )}
      </main>

      <UserEditModal 
        editingUser={editingUser}
        setEditingUser={setEditingUser}
        isLoading={isLoading}
        isResettingPassword={isResettingPassword}
        handleUpdateUserProfile={handleUpdateUserProfile}
        handleSendPasswordReset={handleSendPasswordReset}
      />

      <JobEditModal 
        editingJob={editingJob}
        setEditingJob={setEditingJob}
        isLoading={isLoading}
        handleUpdateJob={handleUpdateJob}
      />
    </div>
  );
};

export default AdminDashboard;
