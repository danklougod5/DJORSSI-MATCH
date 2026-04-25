import React, { useState, useMemo } from 'react';
import { 
  Briefcase, 
  CheckCircle2, 
  Star, 
  Search, 
  Pencil, 
  Trash2, 
  LayoutGrid, 
  Filter, 
  X,
  Calendar,
  MapPin,
  ShieldCheck,
  Zap
} from 'lucide-react';

interface JobsTabProps {
  jobsList: any[];
  jobsSearch: string;
  setJobsSearch: (term: string) => void;
  setEditingJob: (job: any) => void;
  handleDeleteJob: (jobId: string) => Promise<void>;
  handleBulkDeleteJobs: (jobIds: string[]) => Promise<boolean>;
  fetchJobs: () => Promise<void>;
  handleCleanupExpiredJobs: () => Promise<void>;
}

const JobsTab: React.FC<JobsTabProps> = ({
  jobsList,
  jobsSearch,
  setJobsSearch,
  setEditingJob,
  handleDeleteJob,
  handleBulkDeleteJobs,
  fetchJobs,
  handleCleanupExpiredJobs
}) => {
  const [selectedJobIds, setSelectedJobIds] = useState<string[]>([]);
  const [showFilters, setShowFilters] = useState(false);
  
  // Filter states
  const [filterLocation, setFilterLocation] = useState<string>('all');
  const [filterAiVerified, setFilterAiVerified] = useState<string>('all');
  const [filterDateLimit, setFilterDateLimit] = useState<string>('all'); // all, active, expired
  const [filterLevel, setFilterLevel] = useState<string>('all');

  // Derive unique locations and levels for filters
  const locations = useMemo(() => {
    const locs = new Set(jobsList.map(j => j.location).filter(Boolean));
    return Array.from(locs).sort();
  }, [jobsList]);

  const levels = useMemo(() => {
    const lvls = new Set(jobsList.map(j => j.required_level).filter(Boolean));
    return Array.from(lvls).sort();
  }, [jobsList]);

  // Helper to parse DD/MM/YYYY
  const parseDate = (dateStr: string) => {
    if (!dateStr || typeof dateStr !== 'string') return null;
    
    // Try DD/MM/YYYY first since it's the user's primary format
    const parts = dateStr.split('/');
    if (parts.length === 3) {
      const day = parseInt(parts[0], 10);
      const month = parseInt(parts[1], 10) - 1;
      const year = parseInt(parts[2], 10);
      const d = new Date(year, month, day);
      if (!isNaN(d.getTime())) return d;
    }

    // Fallback to standard parsing for ISO or other formats
    let d = new Date(dateStr);
    if (!isNaN(d.getTime())) return d;

    return null;
  };

  // Filtered list
  const filteredJobs = useMemo(() => {
    const now = new Date();
    return jobsList.filter(job => {
      // Text search
      const matchesSearch = 
        !jobsSearch ||
        (job.job_title?.toLowerCase() || '').includes(jobsSearch.toLowerCase()) || 
        (job.company_name?.toLowerCase() || '').includes(jobsSearch.toLowerCase()) ||
        (Array.isArray(job.tags) ? job.tags.join(' ') : (job.tags || '')).toLowerCase().includes(jobsSearch.toLowerCase()) ||
        (job.location?.toLowerCase() || '').includes(jobsSearch.toLowerCase());
      
      if (!matchesSearch) return false;

      // Location filter
      if (filterLocation !== 'all' && job.location !== filterLocation) return false;

      // AI Verified filter
      if (filterAiVerified === 'verified' && !job.is_ai_verified) return false;
      if (filterAiVerified === 'unverified' && job.is_ai_verified) return false;

      // Level filter
      if (filterLevel !== 'all' && job.required_level !== filterLevel) return false;

      // Date Limit filter (Deadline)
      if (filterDateLimit !== 'all') {
        const deadlineDate = parseDate(job.deadline);
        if (deadlineDate) {
          if (filterDateLimit === 'active' && deadlineDate < now) return false;
          if (filterDateLimit === 'expired' && deadlineDate >= now) return false;
        } else if (filterDateLimit === 'expired') {
          // If no date and we want expired, maybe hide it? 
          // Usually untracked dates are considered "active" until proven otherwise
          return false;
        }
      }

      return true;
    });
  }, [jobsList, jobsSearch, filterLocation, filterAiVerified, filterDateLimit, filterLevel]);

  const toggleSelectAll = () => {
    if (selectedJobIds.length === filteredJobs.length) {
      setSelectedJobIds([]);
    } else {
      setSelectedJobIds(filteredJobs.map(j => j.id));
    }
  };

  const toggleSelectJob = (id: string) => {
    setSelectedJobIds(prev => 
      prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
    );
  };

  const onBulkDelete = async () => {
    if (selectedJobIds.length === 0) return;
    const confirmed = await handleBulkDeleteJobs(selectedJobIds);
    // Only clear selection if the user actually confirmed the deletion
    if (confirmed) {
      setSelectedJobIds([]);
    }
  };

  const resetFilters = () => {
    setFilterLocation('all');
    setFilterAiVerified('all');
    setFilterDateLimit('all');
    setFilterLevel('all');
    setJobsSearch('');
  };

  const activeFiltersCount = [
    filterLocation !== 'all',
    filterAiVerified !== 'all',
    filterDateLimit !== 'all',
    filterLevel !== 'all'
  ].filter(Boolean).length;

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Stats Bar */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
         <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center group hover:border-primary/30 transition-all">
            <div>
              <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Total des Offres</p>
              <h4 className="text-2xl font-black text-slate-900">{jobsList.length}</h4>
            </div>
            <div className="w-12 h-12 rounded-xl bg-primary/10 text-primary flex items-center justify-center group-hover:scale-110 transition-transform">
              <Briefcase size={24} />
            </div>
         </div>
         <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center group hover:border-secondary/30 transition-all">
            <div>
              <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Vérifiées par AI</p>
              <h4 className="text-2xl font-black text-secondary">{jobsList.filter(j => j.is_ai_verified).length}</h4>
            </div>
            <div className="w-12 h-12 rounded-xl bg-secondary/10 text-secondary flex items-center justify-center group-hover:scale-110 transition-transform">
              <CheckCircle2 size={24} />
            </div>
         </div>
         <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center group hover:border-cta/30 transition-all">
            <div>
              <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Localisations</p>
              <h4 className="text-2xl font-black text-cta">{new Set(jobsList.map(j => j.location)).size}</h4>
            </div>
            <div className="w-12 h-12 rounded-xl bg-cta/10 text-cta flex items-center justify-center group-hover:scale-110 transition-transform">
              <Star size={24} />
            </div>
         </div>
      </div>

      {/* Action & Filter Bar */}
      <div className="bg-white p-4 rounded-3xl border border-slate-200 shadow-sm space-y-4">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div className="flex items-center gap-4 w-full md:w-auto">
            <div className="relative flex-1 md:w-80">
               <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
               <input 
                 type="text" 
                 value={jobsSearch}
                 onChange={(e) => setJobsSearch(e.target.value)}
                 placeholder="Titre, Entreprise, Mots-clés..." 
                 className="w-full pl-12 pr-4 py-2.5 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-medium text-sm"
               />
            </div>
            <button 
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl font-bold text-sm transition-all border-2 ${
                showFilters || activeFiltersCount > 0 
                ? 'bg-primary/5 border-primary/20 text-primary' 
                : 'bg-white border-slate-100 text-slate-600 hover:border-slate-200'
              }`}
            >
              <Filter size={18} />
              <span>Filtres</span>
              {activeFiltersCount > 0 && (
                <span className="ml-1 w-5 h-5 bg-primary text-white rounded-full flex items-center justify-center text-[10px]">
                  {activeFiltersCount}
                </span>
              )}
            </button>
          </div>

          <div className="flex items-center gap-3 w-full md:w-auto justify-end">
            {selectedJobIds.length > 0 && (
              <div className="flex items-center gap-3 animate-in zoom-in duration-300">
                <span className="text-xs font-black text-primary bg-primary/10 px-3 py-2 rounded-xl border border-primary/20">
                  {selectedJobIds.length} sélectionnés
                </span>
                <button 
                  onClick={onBulkDelete}
                  className="flex items-center gap-2 px-4 py-2.5 bg-red-500 text-white rounded-2xl font-bold text-sm shadow-lg shadow-red-200 hover:bg-red-600 transition-all active:scale-95"
                >
                  <Trash2 size={18} />
                  <span>Supprimer</span>
                </button>
                <button 
                  onClick={() => setSelectedJobIds([])}
                  className="p-2.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-xl transition-all"
                >
                  <X size={20} />
                </button>
              </div>
            )}
            
            <button 
              onClick={() => handleCleanupExpiredJobs()}
              className="px-4 py-2 bg-slate-900 text-white rounded-2xl font-black text-xs uppercase tracking-widest shadow-lg shadow-slate-200 hover:bg-black transition-all active:scale-95 flex items-center gap-2"
              title="Supprimer les offres expirées"
            >
              <Zap size={16} className="text-cta" />
              <span>Nettoyage</span>
            </button>

            <button 
              onClick={() => fetchJobs()}
              className="p-2.5 text-slate-400 hover:text-primary hover:bg-primary/5 rounded-xl transition-all"
              title="Actualiser"
            >
              <Zap size={20} />
            </button>
          </div>
        </div>

        {/* Expandable Advanced Filters */}
        {showFilters && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 p-4 bg-slate-50/50 rounded-2xl border border-slate-100 animate-in slide-in-from-top-4 duration-300">
            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-1">
                <MapPin size={12} /> Localisation
              </label>
              <select 
                value={filterLocation}
                onChange={(e) => setFilterLocation(e.target.value)}
                className="w-full p-2.5 bg-white border border-slate-200 rounded-xl text-sm font-bold focus:ring-2 focus:ring-primary/20 outline-none transition-all appearance-none cursor-pointer"
              >
                <option value="all">Toutes les villes</option>
                {locations.map(loc => (
                  <option key={loc} value={loc}>{loc}</option>
                ))}
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-1">
                <ShieldCheck size={12} /> Vérification AI
              </label>
              <select 
                value={filterAiVerified}
                onChange={(e) => setFilterAiVerified(e.target.value)}
                className="w-full p-2.5 bg-white border border-slate-200 rounded-xl text-sm font-bold focus:ring-2 focus:ring-primary/20 outline-none transition-all appearance-none cursor-pointer"
              >
                <option value="all">Tous les statuts</option>
                <option value="verified">Vérifiés par AI</option>
                <option value="unverified">Non vérifiés</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-1">
                <Calendar size={12} /> Disponibilité
              </label>
              <select 
                value={filterDateLimit}
                onChange={(e) => setFilterDateLimit(e.target.value)}
                className="w-full p-2.5 bg-white border border-slate-200 rounded-xl text-sm font-bold focus:ring-2 focus:ring-primary/20 outline-none transition-all appearance-none cursor-pointer"
              >
                <option value="all">Toutes les dates</option>
                <option value="active">Offres Actives</option>
                <option value="expired">Offres Expirées</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-1">
                <Briefcase size={12} /> Niveau d'études
              </label>
              <div className="flex gap-2">
                <select 
                  value={filterLevel}
                  onChange={(e) => setFilterLevel(e.target.value)}
                  className="flex-1 p-2.5 bg-white border border-slate-200 rounded-xl text-sm font-bold focus:ring-2 focus:ring-primary/20 outline-none transition-all appearance-none cursor-pointer"
                >
                  <option value="all">Tous niveaux</option>
                  {levels.map(lvl => (
                    <option key={lvl} value={lvl}>{lvl}</option>
                  ))}
                </select>
                <button 
                  onClick={resetFilters}
                  className="p-2.5 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-red-500 hover:border-red-100 transition-all"
                  title="Réinitialiser"
                >
                  <X size={20} />
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Table Container */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left whitespace-nowrap min-w-[1600px]">
            <thead className="bg-slate-50/50 text-slate-400 text-[10px] font-black uppercase tracking-[0.15em] border-b border-slate-100">
              <tr>
                <th className="px-6 py-5 w-12">
                  <div className="flex items-center">
                    <input 
                      type="checkbox" 
                      checked={filteredJobs.length > 0 && selectedJobIds.length === filteredJobs.length}
                      onChange={toggleSelectAll}
                      className="w-5 h-5 rounded-lg border-2 border-slate-200 text-primary focus:ring-primary/20 transition-all cursor-pointer"
                    />
                  </div>
                </th>
                <th className="px-6 py-5">Titre</th>
                <th className="px-6 py-5">Entreprise</th>
                <th className="px-6 py-5">Lieu (Ville)</th>
                <th className="px-6 py-5">Date Limite (Deadline)</th>
                <th className="px-6 py-5">Niveau (Diplôme)</th>
                <th className="px-6 py-5">Résumé / Description</th>
                <th className="px-6 py-5">Tags (Mots-clés)</th>
                <th className="px-6 py-5">E-mail de contact</th>
                <th className="px-6 py-5">Statut AI</th>
                <th className="px-6 py-5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredJobs.map(job => {
                const isSelected = selectedJobIds.includes(job.id);
                const deadlineDate = parseDate(job.deadline);
                const isExpired = deadlineDate && deadlineDate < new Date();
                const isNew = job.created_at && (new Date().getTime() - new Date(job.created_at).getTime() < 48 * 60 * 60 * 1000);

                return (
                  <tr 
                    key={job.id} 
                    className={`group transition-all border-l-4 ${
                      isSelected 
                        ? 'bg-primary/[0.02] border-primary ml-1' 
                        : isNew 
                          ? 'bg-green-50/10 border-green-400 hover:bg-green-50/30' 
                          : 'hover:bg-slate-50/50 border-transparent'
                    } cursor-pointer select-none`}
                    onClick={() => toggleSelectJob(job.id)}
                  >
                    <td className="px-6 py-5" onClick={(e) => e.stopPropagation()}>
                       <input 
                        type="checkbox" 
                        checked={isSelected}
                        onChange={() => toggleSelectJob(job.id)}
                        className="w-5 h-5 rounded-lg border-2 border-slate-200 text-primary focus:ring-primary/20 transition-all cursor-pointer"
                      />
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex items-center gap-3">
                        <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-black text-sm shrink-0 border transition-all ${
                          isSelected ? 'bg-primary text-white border-primary shadow-lg shadow-primary/20' : 'bg-slate-50 text-slate-400 border-slate-200 group-hover:border-primary/30 group-hover:text-primary group-hover:bg-primary/5'
                        }`}>
                          {job.company_name?.charAt(0) || <Briefcase size={16} />}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="font-black text-slate-900 text-sm leading-tight group-hover:text-primary transition-all truncate max-w-[150px]" title={job.job_title}>
                              {job.job_title}
                            </p>
                            {isNew && <span className="bg-green-500 text-white text-[9px] font-black px-1.5 py-0.5 rounded-md uppercase tracking-wider shrink-0 animate-pulse">NOUVEAU</span>}
                          </div>
                          <p className="text-[10px] text-slate-400 mt-1 font-mono uppercase">#{job.id.substring(0, 8)}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-tighter truncate max-w-[150px]" title={job.company_name}>
                        {job.company_name || 'Non précisé'}
                      </span>
                    </td>
                    <td className="px-6 py-5">
                      <span className="text-xs font-bold text-slate-600 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-cta"></span> {job.location || 'Côte d\'Ivoire'}
                      </span>
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex flex-col">
                        <span className={`text-xs font-black px-2 py-0.5 rounded-md w-fit bg-slate-100 ${isExpired ? 'text-red-500 bg-red-50' : 'text-slate-500'}`}>
                          {job.deadline || 'Aucune'}
                        </span>
                        {isExpired && <span className="text-[8px] font-black text-red-400 uppercase tracking-tighter mt-1 px-1">Expiré</span>}
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <span className="text-[9px] font-black text-slate-500 uppercase bg-slate-100 px-2 py-0.5 rounded-md">
                        {job.required_level || 'Non défini'}
                      </span>
                    </td>
                    <td className="px-6 py-5">
                      <p className="text-xs text-slate-500 font-medium truncate max-w-[250px] italic" title={job.description}>
                        "{job.description || 'Pas de description'}..."
                      </p>
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex flex-wrap gap-1 max-w-[200px]">
                        {(Array.isArray(job.tags) ? job.tags : []).slice(0, 3).map((tag: string, i: number) => (
                          <span key={i} className="text-[8px] font-black text-primary uppercase bg-primary/5 px-1.5 py-0.5 rounded-full">
                            {tag}
                          </span>
                        ))}
                        {job.tags?.length > 3 && <span className="text-[8px] font-black text-slate-400">+{job.tags.length - 3}</span>}
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <span className="text-xs font-bold text-slate-600 truncate max-w-[150px]" title={job.contact_email}>
                        {job.contact_email || 'Pas d\'email'}
                      </span>
                    </td>
                    <td className="px-6 py-5">
                      {job.is_ai_verified ? (
                        <span className="inline-flex items-center gap-1 px-2 py-1 bg-secondary/10 text-secondary text-[9px] font-black rounded-lg uppercase tracking-wider">
                          <ShieldCheck size={10} /> Vérifié
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2 py-1 bg-slate-100 text-slate-400 text-[9px] font-black rounded-lg uppercase tracking-wider">
                          Non vérifié
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-5 text-right" onClick={(e) => e.stopPropagation()}>
                      <div className="flex justify-end items-center gap-1 opacity-40 group-hover:opacity-100 transition-opacity">
                        <button 
                          onClick={() => setEditingJob({...job})}
                          className="p-2 text-slate-400 hover:text-primary hover:bg-slate-100 rounded-lg transition-colors"
                          title="Modifier l'offre"
                        >
                          <Pencil size={18} />
                        </button>
                        <button 
                          onClick={() => handleDeleteJob(job.id)}
                          className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                          title="Supprimer l'offre"
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
              
              {filteredJobs.length === 0 && (
                <tr>
                  <td colSpan={11} className="px-6 py-20 text-center">
                     <LayoutGrid size={48} className="mx-auto text-slate-100 mb-4" />
                     <p className="text-slate-400 font-bold uppercase tracking-widest text-sm">Aucun résultat correspondant</p>
                     <button 
                        onClick={resetFilters}
                        className="mt-4 text-primary text-xs font-black uppercase hover:underline"
                     >
                        Réinitialiser les filtres
                     </button>
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

export default JobsTab;
