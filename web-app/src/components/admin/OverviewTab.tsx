import React from 'react';
import { Users, CreditCard, Briefcase, MessageSquare, ChevronRight, Smartphone } from 'lucide-react';
import { PieChart, Pie, Cell, ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip } from 'recharts';
import StatCard from './StatCard';

interface OverviewTabProps {
  stats: any;
  userTypeData: any[];
  dailyActivity: any[];
  recentUsersList: any[];
  topSectors: any[];
  COLORS: string[];
  setActiveTab: (tab: any) => void;
  onMakeMePremium: () => void;
  onMakeAllPremium: () => void;
  onRevokeCampaignPremium: () => void;
  isCampaignLoading: boolean;
}

const OverviewTab: React.FC<OverviewTabProps> = ({
  stats,
  userTypeData,
  dailyActivity,
  recentUsersList,
  topSectors,
  COLORS,
  setActiveTab,
  onMakeMePremium,
  onMakeAllPremium,
  onRevokeCampaignPremium,
  isCampaignLoading
}) => {
  return (
    <div className="space-y-8">
      {/* Campaign Section */}
      <div className="bg-gradient-to-r from-orange-500 to-orange-600 p-6 rounded-3xl text-white shadow-xl shadow-orange-200">
         <div className="flex flex-col md:flex-row justify-between items-center gap-6">
            <div className="text-center md:text-left">
               <h3 className="text-xl font-black uppercase tracking-tight">Campagne Fête du Travail 🇨🇮</h3>
               <p className="text-orange-100 font-medium text-sm mt-1">Offrez le Premium à tous vos utilisateurs pour célébrer l'événement !</p>
            </div>
            <div className="flex flex-wrap gap-3">
               <button 
                  onClick={onMakeMePremium}
                  disabled={isCampaignLoading}
                  className="bg-white/20 hover:bg-white/30 backdrop-blur-md text-white px-5 py-2.5 rounded-xl font-bold text-sm transition-all border border-white/20 disabled:opacity-50"
               >
                  {isCampaignLoading ? 'Chargement...' : 'Tester sur moi (24h)'}
               </button>
               <button 
                  onClick={onMakeAllPremium}
                  disabled={isCampaignLoading}
                  className="bg-white text-orange-600 hover:bg-orange-50 px-6 py-2.5 rounded-xl font-black text-sm shadow-lg shadow-orange-900/10 transition-all active:scale-95 disabled:opacity-50"
               >
                  {isCampaignLoading ? 'Opération en cours...' : 'OFFRIR PREMIUM À TOUS (24h)'}
               </button>
               <button 
                  onClick={onRevokeCampaignPremium}
                  disabled={isCampaignLoading}
                  className="bg-red-500 hover:bg-red-600 text-white px-5 py-2.5 rounded-xl font-bold text-sm shadow-lg shadow-red-500/20 transition-all active:scale-95 disabled:opacity-50"
               >
                  {isCampaignLoading ? '...' : 'Annuler l\'offre'}
               </button>
            </div>
         </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard title="Utilisateurs" value={stats.totalUsers.toLocaleString()} icon={<Users />} color="bg-primary" trend="+12% cette semaine" />
        <StatCard title="Abonnés Premium" value={stats.premiumUsers.toLocaleString()} icon={<CreditCard />} color="bg-secondary" trend="+5% cette semaine" />
        <StatCard title="Attente iOS" value={stats.iosWaitlist.toLocaleString()} icon={<Smartphone />} color="bg-black" trend="Demandes iPhone" />
        <StatCard title="Messages" value={stats.pendingFeedback.toLocaleString()} icon={<MessageSquare />} color="bg-primary" trend="3 non lus" />
        <StatCard title="Hommes" value={stats.maleUsers.toLocaleString()} icon={<Users />} color="bg-[#3B82F6]" trend="Sexe masculin" />
        <StatCard title="Femmes" value={stats.femaleUsers.toLocaleString()} icon={<Users />} color="bg-[#EC4899]" trend="Sexe féminin" />
        <StatCard title="Offres Actives" value={stats.activeJobs.toLocaleString()} icon={<Briefcase />} color="bg-secondary" trend="+24 ajoutées" />
      </div>

      <div className="grid lg:grid-cols-3 gap-8">
        {/* Distribution Chart */}
        <div className="lg:col-span-1 bg-white p-6 rounded-2xl border border-slate-200 shadow-sm min-w-0">
           <h3 className="text-lg mb-6">Répartition Premium</h3>
           <div className="h-64 w-full">
              <ResponsiveContainer width="99%" height="100%" minWidth={0}>
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

        {/* Top Sectors list */}
        <div className="lg:col-span-1 bg-white p-6 rounded-2xl border border-slate-200 shadow-sm min-w-0 flex flex-col">
           <h3 className="text-lg mb-6">Secteurs les plus choisis</h3>
           <div className="flex-1 overflow-y-auto w-full custom-scrollbar space-y-3 pr-2" style={{ maxHeight: 'calc(100% - 2rem)' }}>
              {topSectors.map((sector, index) => (
                 <div key={index} className="flex justify-between items-center bg-slate-50 p-3 rounded-xl">
                    <div className="flex items-center gap-3 overflow-hidden">
                       <div className="w-6 h-6 rounded-full bg-primary/10 text-primary flex items-center justify-center text-xs font-bold shrink-0">
                          {index + 1}
                       </div>
                       <span className="text-sm font-medium text-slate-700 truncate">{sector.name}</span>
                    </div>
                    <span className="text-xs font-bold text-primary bg-primary/10 px-2 py-1 rounded-md shrink-0">
                       {sector.count} <Users size={10} className="inline ml-0.5" />
                    </span>
                 </div>
              ))}
              {topSectors.length === 0 && <p className="text-slate-400 text-sm italic text-center py-10">Aucune donnée</p>}
           </div>
        </div>

        {/* Bar Chart */}
        <div className="lg:col-span-1 bg-white p-6 rounded-2xl border border-slate-200 shadow-sm min-w-0">
           <h3 className="text-lg mb-6">Activité Feedback (7j)</h3>
           <div className="h-64 text-xs w-full">
              <ResponsiveContainer width="99%" height="100%" minWidth={0}>
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
  );
};

export default OverviewTab;
