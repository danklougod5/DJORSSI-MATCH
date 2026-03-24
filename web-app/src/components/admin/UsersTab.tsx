import React from 'react';
import { Users, Star, Search, Trash2, Pencil } from 'lucide-react';

interface UsersTabProps {
  stats: any;
  searchTerm: string;
  setSearchTerm: (term: string) => void;
  statusFilter: 'all' | 'premium' | 'free';
  setStatusFilter: (filter: 'all' | 'premium' | 'free') => void;
  recentUsersList: any[];
  handleTogglePremium: (userId: string, currentPremium: boolean) => Promise<void>;
  handleDeleteProfile: (userId: string) => Promise<void>;
  setEditingUser: (user: any) => void;
}

const UsersTab: React.FC<UsersTabProps> = ({
  stats,
  searchTerm,
  setSearchTerm,
  statusFilter,
  setStatusFilter,
  recentUsersList,
  handleTogglePremium,
  handleDeleteProfile,
  setEditingUser
}) => {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
         <div className="bg-white p-4 rounded-xl border border-slate-200 flex justify-between items-center">
            <div>
              <p className="text-xs font-bold text-slate-400 uppercase">Total</p>
              <h4 className="text-xl font-bold">{stats.totalUsers}</h4>
            </div>
            <Users className="text-primary/20" />
         </div>
         <div className="bg-white p-4 rounded-xl border border-slate-200 flex justify-between items-center">
            <div>
              <p className="text-xs font-bold text-slate-400 uppercase">Premium</p>
              <h4 className="text-xl font-bold text-cta">{stats.premiumUsers}</h4>
            </div>
            <Star className="text-cta/20" fill="currentColor" />
         </div>
         <div className="bg-white p-4 rounded-xl border border-slate-200 flex justify-between items-center">
            <div>
              <p className="text-xs font-bold text-slate-400 uppercase">Free</p>
              <h4 className="text-xl font-bold text-slate-500">{stats.totalUsers - stats.premiumUsers}</h4>
            </div>
            <Users className="text-slate-200" />
         </div>
      </div>

      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4 mb-6">
          <div>
            <h3 className="text-xl font-bold text-slate-900">Base de Données Utilisateurs</h3>
            <p className="text-xs text-slate-500">Gérez les accès et surveillez les inscriptions.</p>
          </div>
          
          <div className="flex flex-wrap items-center gap-4 w-full lg:w-auto">
              <div className="flex bg-slate-100 p-1 rounded-lg">
                <button 
                   onClick={() => setStatusFilter('all')}
                   className={`px-3 py-1.5 text-xs font-bold rounded-md transition-all ${statusFilter === 'all' ? 'bg-white shadow-sm text-primary' : 'text-slate-500 hover:text-slate-700'}`}
                >
                   Tous
                </button>
                <button 
                   onClick={() => setStatusFilter('premium')}
                   className={`px-3 py-1.5 text-xs font-bold rounded-md transition-all ${statusFilter === 'premium' ? 'bg-white shadow-sm text-cta' : 'text-slate-500 hover:text-slate-700'}`}
                >
                   Premium
                </button>
                <button 
                   onClick={() => setStatusFilter('free')}
                   className={`px-3 py-1.5 text-xs font-bold rounded-md transition-all ${statusFilter === 'free' ? 'bg-white shadow-sm text-slate-700' : 'text-slate-500 hover:text-slate-700'}`}
                >
                   Free
                </button>
              </div>

              <div className="relative flex-1 lg:w-64">
                 <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
                 <input 
                   type="text" 
                   value={searchTerm}
                   onChange={(e) => setSearchTerm(e.target.value)}
                   placeholder="Rechercher (Nom, Mobile...)" 
                   className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                 />
              </div>
          </div>
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full text-left whitespace-nowrap">
            <thead className="bg-slate-50 text-slate-500 text-[10px] font-black uppercase tracking-widest border-b border-slate-100">
              <tr>
                <th className="px-6 py-4">Participant</th>
                <th className="px-6 py-4">Contact & Compétences</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4">Inscription</th>
                <th className="px-6 py-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {recentUsersList
                .filter(user => {
                  const matchesSearch = user.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
                                        user.phone.includes(searchTerm);
                  const matchesFilter = statusFilter === 'all' || 
                                        (statusFilter === 'premium' && user.premium) || 
                                        (statusFilter === 'free' && !user.premium);
                  return matchesSearch && matchesFilter;
                })
                .map(user => (
                <tr key={user.id} className="hover:bg-slate-50/50 transition-colors group">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold text-sm ${user.premium ? 'bg-cta text-white' : 'bg-slate-100 text-slate-400'}`}>
                        {user.name.charAt(0)}
                      </div>
                      <div>
                          <p className="font-bold text-slate-900 leading-none">{user.name}</p>
                          <p className="text-[10px] text-slate-400 mt-1 font-mono uppercase">#{user.id.substring(0, 8)}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                      <p className="text-sm font-semibold text-slate-700">{user.phone}</p>
                      <p className="text-xs text-slate-400">{user.sector}</p>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-2.5 py-1 rounded-lg text-[10px] font-black uppercase tracking-tight ${user.premium ? 'bg-cta text-white shadow-sm shadow-cta/20' : 'bg-slate-100 text-slate-500'}`}>
                      {user.premium ? 'Premium' : 'Standard'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                      <p className="text-xs font-medium text-slate-500">{user.date}</p>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <div className="flex justify-end gap-1 opacity-40 group-hover:opacity-100 transition-opacity">
                      <button 
                        onClick={() => handleTogglePremium(user.id, user.premium)}
                        className={`p-2 rounded-lg transition-colors ${user.premium ? 'text-cta hover:bg-cta/10' : 'text-slate-400 hover:text-cta hover:bg-slate-100'}`}
                        title={user.premium ? "Rétrograder en Standard" : "Passer en Premium"}
                      >
                        <Star size={18} fill={user.premium ? "currentColor" : "none"} />
                      </button>
                      <button 
                        onClick={() => handleDeleteProfile(user.id)}
                        className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                        title="Définitivement Supprimer"
                      >
                        <Trash2 size={18} />
                      </button>
                      <button 
                        onClick={() => setEditingUser({...user})}
                        className="p-2 text-slate-400 hover:text-primary hover:bg-slate-100 rounded-lg transition-colors"
                        title="Modifier le Profil"
                      >
                        <Pencil size={18} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {recentUsersList.length === 0 && (
                  <tr>
                      <td colSpan={5} className="px-6 py-20 text-center">
                          <Users size={40} className="mx-auto text-slate-200 mb-2" />
                          <p className="text-slate-400 italic">Aucun utilisateur trouvé.</p>
                      </td>
                  </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default UsersTab;
