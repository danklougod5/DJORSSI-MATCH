import React, { useState, useMemo } from 'react';
import { 
  CheckSquare, 
  Trash2, 
  MapPin, 
  Mail, 
  Phone, 
  Calendar, 
  AlertCircle, 
  Search,
  CheckCircle,
  Clock,
  ChevronDown,
  ChevronUp,
  Briefcase,
  Pencil,
  Building
} from 'lucide-react';
import { formatEffectiveJobDeadline } from '../../lib/dateUtils';

interface JobApprovalTabProps {
  jobsList: any[];
  handleApproveJob: (jobId: string) => Promise<void>;
  handleDeleteJob: (jobId: string) => Promise<void>;
  setEditingJob: (job: any) => void;
  fetchJobs: () => Promise<void>;
}

const JobApprovalTab: React.FC<JobApprovalTabProps> = ({
  jobsList,
  handleApproveJob,
  handleDeleteJob,
  setEditingJob,
  fetchJobs
}) => {
  const [activeSubTab, setActiveSubTab] = useState<'pending' | 'recruiters'>('pending');
  const [searchPending, setSearchPending] = useState('');
  const [searchRecruiters, setSearchRecruiters] = useState('');
  const [expandedRecruiterKey, setExpandedRecruiterKey] = useState<string | null>(null);

  // Helper to parse dates
  const formatDate = (dateStr: string) => {
    if (!dateStr) return 'Non spécifié';
    try {
      const date = new Date(dateStr);
      if (isNaN(date.getTime())) return dateStr;
      return date.toLocaleDateString('fr-FR', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return dateStr;
    }
  };

  // 1. Recruiter Jobs
  const recruiterJobs = useMemo(() => {
    return jobsList.filter(job => job.source_url && job.source_url.startsWith('recruiter_post_'));
  }, [jobsList]);

  // 2. Pending Jobs (needs approval)
  const pendingJobs = useMemo(() => {
    return jobsList.filter(job => job.is_approved === false);
  }, [jobsList]);

  // Filtered Pending Jobs
  const filteredPendingJobs = useMemo(() => {
    if (!searchPending) return pendingJobs;
    const term = searchPending.toLowerCase();
    return pendingJobs.filter(job => 
      (job.job_title?.toLowerCase() || '').includes(term) ||
      (job.company_name?.toLowerCase() || '').includes(term) ||
      (job.location?.toLowerCase() || '').includes(term) ||
      (job.description?.toLowerCase() || '').includes(term)
    );
  }, [pendingJobs, searchPending]);

  // 3. Recruiter Metrics aggregation
  const recruiterMetrics = useMemo(() => {
    const recruiters: Record<string, {
      key: string;
      companyName: string;
      email: string;
      whatsapp: string;
      total: number;
      pending: number;
      approved: number;
      lastSubmitted: string;
      jobs: any[];
    }> = {};

    recruiterJobs.forEach(job => {
      const company = job.company_name || 'Entreprise Inconnue';
      const email = job.contact_email || 'Non renseigné';
      const whatsapp = job.whatsapp_number || 'Non renseigné';
      
      // Group by company name + whatsapp + email to be safe and aggregate correct entities
      const key = `${company.toLowerCase().trim()}_${whatsapp.trim()}_${email.toLowerCase().trim()}`;

      if (!recruiters[key]) {
        recruiters[key] = {
          key,
          companyName: company,
          email,
          whatsapp,
          total: 0,
          pending: 0,
          approved: 0,
          lastSubmitted: job.created_at || '',
          jobs: []
        };
      }

      const rec = recruiters[key];
      rec.total += 1;
      if (job.is_approved === false) {
        rec.pending += 1;
      } else {
        rec.approved += 1;
      }
      rec.jobs.push(job);

      if (job.created_at && (!rec.lastSubmitted || new Date(job.created_at) > new Date(rec.lastSubmitted))) {
        rec.lastSubmitted = job.created_at;
      }
    });

    // Sort by total jobs submitted descending
    return Object.values(recruiters).sort((a, b) => b.total - a.total);
  }, [recruiterJobs]);

  // Filtered Recruiters
  const filteredRecruiters = useMemo(() => {
    if (!searchRecruiters) return recruiterMetrics;
    const term = searchRecruiters.toLowerCase();
    return recruiterMetrics.filter(rec => 
      rec.companyName.toLowerCase().includes(term) ||
      rec.email.toLowerCase().includes(term) ||
      rec.whatsapp.toLowerCase().includes(term)
    );
  }, [recruiterMetrics, searchRecruiters]);

  // Totals for top cards
  const stats = useMemo(() => {
    return {
      totalPending: pendingJobs.length,
      totalRecruiters: recruiterMetrics.length,
      totalApprovedRecruiterJobs: recruiterJobs.length - pendingJobs.filter(j => j.source_url?.startsWith('recruiter_post_')).length
    };
  }, [pendingJobs, recruiterMetrics, recruiterJobs]);

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      
      {/* Top Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Pending Card */}
        <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm flex justify-between items-center hover:border-amber-300 transition-all duration-300">
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Offres en Attente</p>
            <h4 className="text-3xl font-black text-amber-500">{stats.totalPending}</h4>
            <p className="text-xs text-slate-400 mt-1">Nécessitent une validation</p>
          </div>
          <div className="w-14 h-14 rounded-2xl bg-amber-500/10 text-amber-500 flex items-center justify-center">
            <Clock size={28} />
          </div>
        </div>

        {/* Total Recruiters Card */}
        <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm flex justify-between items-center hover:border-primary/30 transition-all duration-300">
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Recruteurs Actifs</p>
            <h4 className="text-3xl font-black text-slate-900">{stats.totalRecruiters}</h4>
            <p className="text-xs text-slate-400 mt-1">Unique par coordonnées</p>
          </div>
          <div className="w-14 h-14 rounded-2xl bg-primary/10 text-primary flex items-center justify-center">
            <Building size={28} />
          </div>
        </div>

        {/* Approved Recruiter Jobs Card */}
        <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm flex justify-between items-center hover:border-green-300 transition-all duration-300">
          <div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">Offres Approuvées</p>
            <h4 className="text-3xl font-black text-green-600">{stats.totalApprovedRecruiterJobs}</h4>
            <p className="text-xs text-slate-400 mt-1">Visibles sur l'application mobile</p>
          </div>
          <div className="w-14 h-14 rounded-2xl bg-green-50/80 text-green-600 flex items-center justify-center">
            <CheckCircle size={28} />
          </div>
        </div>
      </div>

      {/* Tabs Menu */}
      <div className="flex border-b border-slate-200">
        <button
          onClick={() => setActiveSubTab('pending')}
          className={`pb-4 px-6 font-bold text-sm transition-all relative ${
            activeSubTab === 'pending'
              ? 'text-primary'
              : 'text-slate-400 hover:text-slate-600'
          }`}
        >
          <div className="flex items-center gap-2">
            <Clock size={16} />
            <span>Offres en Attente d'Approbation</span>
            {stats.totalPending > 0 && (
              <span className="bg-amber-500 text-white text-[10px] px-2 py-0.5 rounded-full font-black">
                {stats.totalPending}
              </span>
            )}
          </div>
          {activeSubTab === 'pending' && (
            <div className="absolute bottom-0 left-0 right-0 h-1 bg-primary rounded-t-full" />
          )}
        </button>

        <button
          onClick={() => setActiveSubTab('recruiters')}
          className={`pb-4 px-6 font-bold text-sm transition-all relative ${
            activeSubTab === 'recruiters'
              ? 'text-primary'
              : 'text-slate-400 hover:text-slate-600'
          }`}
        >
          <div className="flex items-center gap-2">
            <Building size={16} />
            <span>Statistiques Recruteurs</span>
            <span className="bg-slate-100 text-slate-500 text-[10px] px-2 py-0.5 rounded-full font-black">
              {stats.totalRecruiters}
            </span>
          </div>
          {activeSubTab === 'recruiters' && (
            <div className="absolute bottom-0 left-0 right-0 h-1 bg-primary rounded-t-full" />
          )}
        </button>
      </div>

      {/* Tab Content 1: Pending Job Offers */}
      {activeSubTab === 'pending' && (
        <div className="space-y-6">
          <div className="flex justify-between items-center">
            <div className="relative w-full md:w-80">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input
                type="text"
                value={searchPending}
                onChange={(e) => setSearchPending(e.target.value)}
                placeholder="Rechercher une offre d'emploi..."
                className="w-full pl-12 pr-4 py-2.5 bg-white border border-slate-200 rounded-2xl focus:border-primary outline-none transition-all font-medium text-sm shadow-sm"
              />
            </div>
            <button 
              onClick={() => fetchJobs()}
              className="px-4 py-2 bg-slate-900 text-white rounded-xl text-xs font-black uppercase tracking-wider hover:bg-black transition-all active:scale-95 shadow-sm"
            >
              Actualiser
            </button>
          </div>

          {filteredPendingJobs.length > 0 ? (
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
              {filteredPendingJobs.map((job) => (
                <div 
                  key={job.id} 
                  className="bg-white border border-slate-200 rounded-3xl p-6 shadow-sm flex flex-col justify-between hover:shadow-md transition-all duration-300 relative overflow-hidden"
                >
                  {/* Decorative badge indicating recruiter submission */}
                  <div className="absolute top-0 right-0 bg-amber-500 text-white text-[9px] font-black uppercase px-3 py-1 rounded-bl-xl tracking-wider">
                    En Attente de Validation
                  </div>

                  <div>
                    {/* Header */}
                    <div className="flex gap-4 items-start mb-4">
                      <div className="w-12 h-12 rounded-2xl bg-primary/10 text-primary flex items-center justify-center font-black text-lg shrink-0">
                        {job.company_name?.charAt(0) || <Briefcase size={20} />}
                      </div>
                      <div className="pr-16">
                        <h4 className="font-black text-slate-900 text-base leading-tight mb-1">{job.job_title}</h4>
                        <p className="text-xs font-bold text-slate-400 uppercase tracking-wide flex items-center gap-1.5">
                          <Building size={12} /> {job.company_name}
                        </p>
                      </div>
                    </div>

                    {/* Metadata Badges */}
                    <div className="flex flex-wrap gap-2 mb-4">
                      {job.contract_type && (
                        <span className="text-[10px] font-black uppercase bg-primary/5 text-primary px-2.5 py-1 rounded-lg">
                          {job.contract_type}
                        </span>
                      )}
                      {job.required_level && (
                        <span className="text-[10px] font-black uppercase bg-slate-100 text-slate-600 px-2.5 py-1 rounded-lg">
                          Niveau: {job.required_level}
                        </span>
                      )}
                      {job.salary_range && (
                        <span className="text-[10px] font-black uppercase bg-green-50 text-green-700 px-2.5 py-1 rounded-lg">
                          {job.salary_range}
                        </span>
                      )}
                    </div>

                    {/* Contact details */}
                    <div className="bg-slate-50 rounded-2xl p-4 space-y-2 mb-4 text-xs">
                      <p className="font-bold text-slate-500 uppercase tracking-widest text-[9px] mb-1">Moyens de contact fournis</p>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        {job.contact_email ? (
                          <a 
                            href={`mailto:${job.contact_email}`} 
                            className="flex items-center gap-2 text-slate-700 hover:text-primary transition-colors font-semibold truncate"
                          >
                            <Mail size={14} className="text-slate-400 shrink-0" />
                            <span className="truncate">{job.contact_email}</span>
                          </a>
                        ) : (
                          <div className="flex items-center gap-2 text-slate-400 italic">
                            <Mail size={14} className="shrink-0" />
                            <span>Aucun email</span>
                          </div>
                        )}

                        {job.whatsapp_number ? (
                          <a 
                            href={`https://wa.me/${job.whatsapp_number}`} 
                            target="_blank" 
                            rel="noopener noreferrer" 
                            className="flex items-center gap-2 text-slate-700 hover:text-green-600 transition-colors font-semibold truncate"
                          >
                            <Phone size={14} className="text-green-500 shrink-0" />
                            <span className="truncate">+{job.whatsapp_number} (WhatsApp)</span>
                          </a>
                        ) : (
                          <div className="flex items-center gap-2 text-slate-400 italic">
                            <Phone size={14} className="shrink-0" />
                            <span>Aucun WhatsApp</span>
                          </div>
                        )}
                      </div>
                      
                      <div className="flex items-center gap-2 pt-2 border-t border-slate-200/60 text-[11px] text-slate-500">
                        <MapPin size={12} className="text-slate-400" />
                        <span>Lieu : <strong>{job.location || 'Abidjan'}</strong></span>
                        {formatEffectiveJobDeadline(job) && (
                          <span className="ml-auto flex items-center gap-1">
                            <Calendar size={12} /> Expire : <strong>{formatEffectiveJobDeadline(job)}</strong>
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Description */}
                    <div className="mb-4">
                      <p className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1">Description</p>
                      <div className="text-slate-600 text-xs leading-relaxed max-h-32 overflow-y-auto bg-slate-50/50 p-3 rounded-2xl border border-slate-100 italic">
                        {job.description || "Aucune description fournie."}
                      </div>
                    </div>

                    {/* Tags */}
                    {job.tags && job.tags.length > 0 && (
                      <div className="mb-4">
                        <div className="flex flex-wrap gap-1">
                          {job.tags.map((tag: string, i: number) => (
                            <span key={i} className="text-[9px] font-black text-slate-500 uppercase bg-slate-100 px-2 py-0.5 rounded-full">
                              #{tag}
                            </span>
                          ))}
                        </div>
                      </div>
                    )}

                    {/* Cover Letter Requirements */}
                    {job.requires_cover_letter && (
                      <div className="mb-4 p-3 bg-orange-50 border border-orange-100 rounded-2xl text-xs">
                        <p className="font-bold text-orange-800 flex items-center gap-1.5">
                          <AlertCircle size={14} /> Lettre de motivation exigée
                        </p>
                        {job.cover_letter_instructions && (
                          <p className="text-orange-700/80 mt-1 italic">"{job.cover_letter_instructions}"</p>
                        )}
                      </div>
                    )}

                    <div className="text-[10px] text-slate-400 mt-2 font-mono">
                      Soumis le : {formatDate(job.created_at)}
                    </div>
                  </div>

                  {/* Actions footer */}
                  <div className="flex items-center gap-3 pt-6 mt-6 border-t border-slate-100">
                    <button
                      onClick={() => handleApproveJob(job.id)}
                      className="flex-1 flex items-center justify-center gap-2 py-3 bg-green-500 hover:bg-green-600 text-white rounded-2xl font-black text-xs uppercase tracking-widest shadow-lg shadow-green-100 transition-all active:scale-95 cursor-pointer"
                    >
                      <CheckCircle size={16} />
                      <span>Approuver l'offre</span>
                    </button>
                    
                    <button
                      onClick={() => setEditingJob({...job})}
                      className="p-3 text-slate-500 hover:text-primary hover:bg-primary/5 rounded-2xl border border-slate-200 transition-all"
                      title="Modifier les détails avant d'approuver"
                    >
                      <Pencil size={18} />
                    </button>

                    <button
                      onClick={() => handleDeleteJob(job.id)}
                      className="p-3 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-2xl border border-slate-200 hover:border-red-200 transition-all"
                      title="Rejeter et supprimer"
                    >
                      <Trash2 size={18} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="bg-white rounded-3xl p-16 text-center border border-slate-200">
              <CheckSquare size={48} className="mx-auto text-slate-200 mb-4" />
              <h5 className="text-slate-800 font-black text-base uppercase tracking-wider">Aucune offre en attente</h5>
              <p className="text-slate-400 text-xs mt-1">Toutes les soumissions des recruteurs ont été traitées.</p>
            </div>
          )}
        </div>
      )}

      {/* Tab Content 2: Recruiter metrics */}
      {activeSubTab === 'recruiters' && (
        <div className="space-y-6">
          <div className="flex justify-between items-center">
            <div className="relative w-full md:w-80">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
              <input
                type="text"
                value={searchRecruiters}
                onChange={(e) => setSearchRecruiters(e.target.value)}
                placeholder="Rechercher un recruteur..."
                className="w-full pl-12 pr-4 py-2.5 bg-white border border-slate-200 rounded-2xl focus:border-primary outline-none transition-all font-medium text-sm shadow-sm"
              />
            </div>
          </div>

          <div className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left whitespace-nowrap">
                <thead className="bg-slate-50/50 text-slate-400 text-[10px] font-black uppercase tracking-wider border-b border-slate-100">
                  <tr>
                    <th className="px-6 py-5">Recruteur / Entreprise</th>
                    <th className="px-6 py-5">WhatsApp</th>
                    <th className="px-6 py-5">E-mail</th>
                    <th className="px-6 py-5 text-center">Offres en attente</th>
                    <th className="px-6 py-5 text-center">Offres approuvées</th>
                    <th className="px-6 py-5 text-center">Total Soumises</th>
                    <th className="px-6 py-5">Dernière soumission</th>
                    <th className="px-6 py-5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredRecruiters.map((rec) => {
                    const isExpanded = expandedRecruiterKey === rec.key;

                    return (
                      <React.Fragment key={rec.key}>
                        {/* Summary Row */}
                        <tr 
                          onClick={() => setExpandedRecruiterKey(isExpanded ? null : rec.key)}
                          className="hover:bg-slate-50/50 transition-colors cursor-pointer select-none group"
                        >
                          <td className="px-6 py-5">
                            <div className="flex items-center gap-3">
                              <div className="w-9 h-9 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-center text-slate-500 font-bold group-hover:text-primary group-hover:border-primary/20 transition-all">
                                {rec.companyName.charAt(0)}
                              </div>
                              <span className="font-black text-slate-800 text-sm">{rec.companyName}</span>
                            </div>
                          </td>
                          <td className="px-6 py-5">
                            {rec.whatsapp !== 'Non renseigné' ? (
                              <a 
                                href={`https://wa.me/${rec.whatsapp}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                onClick={(e) => e.stopPropagation()}
                                className="inline-flex items-center gap-1.5 text-xs text-slate-600 hover:text-green-600 font-bold"
                              >
                                <Phone size={12} className="text-green-500" />
                                <span>+{rec.whatsapp}</span>
                              </a>
                            ) : (
                              <span className="text-xs text-slate-400 italic">Aucun</span>
                            )}
                          </td>
                          <td className="px-6 py-5">
                            {rec.email !== 'Non renseigné' ? (
                              <a 
                                href={`mailto:${rec.email}`}
                                onClick={(e) => e.stopPropagation()}
                                className="inline-flex items-center gap-1.5 text-xs text-slate-600 hover:text-primary font-bold"
                              >
                                <Mail size={12} className="text-slate-400" />
                                <span>{rec.email}</span>
                              </a>
                            ) : (
                              <span className="text-xs text-slate-400 italic">Aucun</span>
                            )}
                          </td>
                          <td className="px-6 py-5 text-center">
                            {rec.pending > 0 ? (
                              <span className="bg-amber-100 text-amber-700 text-xs font-bold px-2 py-0.5 rounded-full">
                                {rec.pending}
                              </span>
                            ) : (
                              <span className="text-slate-400 text-xs font-medium">-</span>
                            )}
                          </td>
                          <td className="px-6 py-5 text-center">
                            {rec.approved > 0 ? (
                              <span className="bg-green-50 text-green-700 text-xs font-bold px-2 py-0.5 rounded-full">
                                {rec.approved}
                              </span>
                            ) : (
                              <span className="text-slate-400 text-xs font-medium">-</span>
                            )}
                          </td>
                          <td className="px-6 py-5 text-center">
                            <span className="font-mono font-black text-slate-800 bg-slate-50 px-2 py-1 rounded-lg border border-slate-100">
                              {rec.total}
                            </span>
                          </td>
                          <td className="px-6 py-5 text-xs text-slate-500 font-mono">
                            {formatDate(rec.lastSubmitted)}
                          </td>
                          <td className="px-6 py-5 text-right">
                            <button className="text-slate-400 hover:text-slate-800 transition-colors">
                              {isExpanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
                            </button>
                          </td>
                        </tr>

                        {/* Collapsible Details Row containing Recruiter's jobs */}
                        {isExpanded && (
                          <tr className="bg-slate-50/50">
                            <td colSpan={8} className="px-8 py-6 border-t border-b border-slate-100">
                              <h5 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-4">
                                Historique des offres soumises par {rec.companyName}
                              </h5>
                              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {rec.jobs.map(job => (
                                  <div 
                                    key={job.id} 
                                    className="bg-white border border-slate-150 rounded-2xl p-4 shadow-xs flex flex-col justify-between hover:border-slate-300 transition-all"
                                  >
                                    <div>
                                      <div className="flex justify-between items-start mb-2">
                                        <h6 className="font-bold text-slate-900 text-sm leading-tight">{job.job_title}</h6>
                                        {job.is_approved !== false ? (
                                          <span className="inline-flex items-center gap-0.5 text-[8px] font-black uppercase text-green-700 bg-green-50 px-1.5 py-0.5 rounded">
                                            Approuvé
                                          </span>
                                        ) : (
                                          <span className="inline-flex items-center gap-0.5 text-[8px] font-black uppercase text-amber-700 bg-amber-50 px-1.5 py-0.5 rounded animate-pulse">
                                            En attente
                                          </span>
                                        )}
                                      </div>
                                      
                                      <div className="flex flex-wrap gap-1.5 mb-2 text-[10px]">
                                        <span className="text-slate-500 font-semibold">{job.contract_type || 'CDI'}</span>
                                        <span className="text-slate-350">•</span>
                                        <span className="text-slate-500 font-semibold">{job.location || 'Abidjan'}</span>
                                        {job.salary_range && (
                                          <>
                                            <span className="text-slate-350">•</span>
                                            <span className="text-green-600 font-bold">{job.salary_range}</span>
                                          </>
                                        )}
                                      </div>

                                      <p className="text-slate-500 text-[11px] leading-relaxed line-clamp-2 italic">
                                        "{job.description || 'Pas de description'}"
                                      </p>
                                    </div>

                                    {/* Action row */}
                                    <div className="flex gap-2 justify-end mt-4 pt-3 border-t border-slate-100">
                                      {job.is_approved === false && (
                                        <button
                                          onClick={() => handleApproveJob(job.id)}
                                          className="px-2.5 py-1.5 bg-green-500 hover:bg-green-600 text-white rounded-lg font-bold text-[10px] uppercase tracking-wide flex items-center gap-1 shadow-sm active:scale-95"
                                        >
                                          <CheckCircle size={10} />
                                          <span>Approuver</span>
                                        </button>
                                      )}
                                      
                                      <button
                                        onClick={() => setEditingJob({...job})}
                                        className="p-1.5 text-slate-500 hover:text-primary hover:bg-slate-100 rounded-lg transition-colors border border-slate-200"
                                        title="Modifier"
                                      >
                                        <Pencil size={12} />
                                      </button>

                                      <button
                                        onClick={() => handleDeleteJob(job.id)}
                                        className="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors border border-slate-200 hover:border-red-200"
                                        title="Supprimer"
                                      >
                                        <Trash2 size={12} />
                                      </button>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </td>
                          </tr>
                        )}
                      </React.Fragment>
                    );
                  })}

                  {filteredRecruiters.length === 0 && (
                    <tr>
                      <td colSpan={8} className="px-6 py-12 text-center text-slate-400 italic">
                        Aucun recruteur trouvé.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};

export default JobApprovalTab;
