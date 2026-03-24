import React from 'react';
import { Briefcase, CheckCircle2, Star, Search, Pencil, Trash2, LayoutGrid } from 'lucide-react';

interface JobsTabProps {
  jobsList: any[];
  jobsSearch: string;
  setJobsSearch: (term: string) => void;
  setEditingJob: (job: any) => void;
  handleDeleteJob: (jobId: string) => Promise<void>;
}

const JobsTab: React.FC<JobsTabProps> = ({
  jobsList,
  jobsSearch,
  setJobsSearch,
  setEditingJob,
  handleDeleteJob
}) => {
  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Stats Bar for Jobs */}
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

      {/* Jobs Management Table */}
      <div className="bg-white p-6 md:p-8 rounded-3xl border border-slate-200 shadow-sm space-y-6">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h3 className="text-xl font-black text-slate-900 uppercase tracking-tight">Répertoire des Offres</h3>
            <p className="text-xs text-slate-500 font-medium">Gérez l'ensemble des annonces visibles par les utilisateurs.</p>
          </div>
          <div className="relative w-full md:w-80">
             <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
             <input 
               type="text" 
               value={jobsSearch}
               onChange={(e) => setJobsSearch(e.target.value)}
               placeholder="Titre, Entreprise, Mots-clés..." 
               className="w-full pl-12 pr-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-medium text-sm"
             />
          </div>
        </div>

        <div className="overflow-x-auto -mx-6 md:mx-0">
          <table className="w-full text-left whitespace-nowrap min-w-[1600px]">
            <thead className="bg-slate-50/50 text-slate-400 text-[10px] font-black uppercase tracking-[0.15em] border-y border-slate-100">
              <tr>
                <th className="px-6 py-5">Titre</th>
                <th className="px-6 py-5">Entreprise</th>
                <th className="px-6 py-5">Lieu (Ville)</th>
                <th className="px-6 py-5">Niveau (Diplôme)</th>
                <th className="px-6 py-5">Date Limite (Deadline)</th>
                <th className="px-6 py-5">Résumé / Description</th>
                <th className="px-6 py-5">Tags (Mots-clés)</th>
                <th className="px-6 py-5">E-mail de contact</th>
                <th className="px-6 py-5">URL Source</th>
                <th className="px-6 py-5">Fourchette de salaire</th>
                <th className="px-6 py-5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {jobsList
                .filter(job => 
                  (job.job_title?.toLowerCase() || '').includes(jobsSearch.toLowerCase()) || 
                  (job.company_name?.toLowerCase() || '').includes(jobsSearch.toLowerCase()) ||
                  (Array.isArray(job.tags) ? job.tags.join(' ') : (job.tags || '')).toLowerCase().includes(jobsSearch.toLowerCase())
                )
                .map(job => (
                <tr 
                  key={job.id} 
                  onClick={() => setEditingJob({...job})}
                  className="hover:bg-slate-50/80 transition-all group border-transparent hover:border-primary/10 cursor-pointer"
                >
                  <td className="px-6 py-5">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-black text-sm shrink-0 border border-primary/20 group-hover:bg-primary group-hover:text-white transition-all">
                        {job.company_name?.charAt(0) || <Briefcase size={16} />}
                      </div>
                      <div>
                        <p className="font-black text-slate-900 text-sm leading-tight group-hover:text-primary transition-all truncate max-w-[200px]" title={job.job_title}>
                          {job.job_title}
                        </p>
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
                    <span className="text-[9px] font-black text-slate-500 uppercase bg-slate-100 px-2 py-0.5 rounded-md">
                      {job.required_level || 'Non défini'}
                    </span>
                  </td>
                  <td className="px-6 py-5">
                    <span className="text-xs font-medium text-slate-500">
                      {job.deadline || 'Aucune'}
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
                    <a 
                      href={job.source_url || job.application_link} 
                      target="_blank" 
                      rel="noopener noreferrer" 
                      onClick={(e) => e.stopPropagation()}
                      className="text-xs font-bold text-primary hover:underline truncate max-w-[150px]"
                    >
                      {job.source_url || job.application_link ? (job.source_url || job.application_link).substring(0, 30) + '...' : 'Pas d\'URL'}
                    </a>
                  </td>
                  <td className="px-6 py-5">
                    <span className="text-xs font-black text-slate-700 uppercase tracking-tighter">
                      {job.salary_range || 'A discuter'}
                    </span>
                  </td>
                  <td className="px-6 py-5 text-right" onClick={(e) => e.stopPropagation()}>
                    <div className="flex justify-end items-center gap-1 opacity-40 group-hover:opacity-100 transition-opacity">
                      <button 
                        onClick={(e) => { e.stopPropagation(); setEditingJob({...job}); }}
                        className="p-2 text-slate-400 hover:text-primary hover:bg-slate-100 rounded-lg transition-colors"
                        title="Modifier l'offre"
                      >
                        <Pencil size={18} />
                      </button>
                      <button 
                        onClick={(e) => { e.stopPropagation(); handleDeleteJob(job.id); }}
                        className="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                        title="Supprimer l'offre"
                      >
                        <Trash2 size={18} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {jobsList.length === 0 && (
                <tr>
                  <td colSpan={11} className="px-6 py-20 text-center">
                     <LayoutGrid size={48} className="mx-auto text-slate-100 mb-4" />
                     <p className="text-slate-400 font-bold uppercase tracking-widest text-sm">Aucune offre dans la base</p>
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
