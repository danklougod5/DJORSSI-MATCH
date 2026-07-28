import React, { useState, useMemo } from 'react';
import { 
  ShieldAlert, 
  Trash2, 
  Check, 
  AlertTriangle, 
  Calendar, 
  User, 
  Briefcase, 
  RefreshCw, 
  MessageSquare, 
  UserX, 
  UserCheck, 
  Building2, 
  Search, 
  AlertCircle
} from 'lucide-react';

interface ReportItem {
  id: string;
  reason: string;
  details: string | null;
  created_at: string;
  user_id: string;
  reported_user_id?: string | null;
  profiles: {
    full_name: string | null;
  } | null;
  reported_profile?: {
    id: string;
    full_name: string | null;
    company_name: string | null;
    phone_number: string | null;
    is_blocked: boolean;
    is_recruiter: boolean;
  } | null;
  jobs: {
    id: string;
    job_title: string;
    company_name: string;
    location: string;
  } | null;
}

interface ReportsTabProps {
  reportsList: ReportItem[];
  isLoading: boolean;
  handleDeleteJob: (jobId: string) => Promise<void>;
  handleDismissReport: (reportId: string) => Promise<void>;
  handleToggleBlockUser?: (userId: string, currentBlocked: boolean) => Promise<void>;
  fetchReports: () => Promise<void>;
}

const ReportsTab: React.FC<ReportsTabProps> = ({
  reportsList,
  isLoading,
  handleDeleteJob,
  handleDismissReport,
  handleToggleBlockUser,
  fetchReports
}) => {
  const [activeFilter, setActiveFilter] = useState<'all' | 'recruiters' | 'candidates' | 'jobs'>('all');
  const [searchTerm, setSearchTerm] = useState('');

  // Metrics
  const totalCount = reportsList.length;
  const recruiterCount = reportsList.filter(r => r.reported_profile && r.reported_profile.is_recruiter).length;
  const candidateCount = reportsList.filter(r => r.reported_profile && !r.reported_profile.is_recruiter).length;
  const jobCount = reportsList.filter(r => r.jobs != null).length;

  const filteredReports = useMemo(() => {
    return reportsList.filter(report => {
      // 1. Role / Type Filter
      if (activeFilter === 'recruiters') {
        if (!report.reported_profile || !report.reported_profile.is_recruiter) return false;
      } else if (activeFilter === 'candidates') {
        if (!report.reported_profile || report.reported_profile.is_recruiter) return false;
      } else if (activeFilter === 'jobs') {
        if (!report.jobs) return false;
      }

      // 2. Search Filter
      if (!searchTerm.trim()) return true;
      const term = searchTerm.toLowerCase();

      const reporterName = report.profiles?.full_name?.toLowerCase() || '';
      const reportedName = report.reported_profile?.full_name?.toLowerCase() || '';
      const reportedCompany = report.reported_profile?.company_name?.toLowerCase() || '';
      const reportedPhone = report.reported_profile?.phone_number?.toLowerCase() || '';
      const jobTitle = report.jobs?.job_title?.toLowerCase() || '';
      const jobCompany = report.jobs?.company_name?.toLowerCase() || '';
      const reason = report.reason?.toLowerCase() || '';
      const details = report.details?.toLowerCase() || '';

      return (
        reporterName.includes(term) ||
        reportedName.includes(term) ||
        reportedCompany.includes(term) ||
        reportedPhone.includes(term) ||
        jobTitle.includes(term) ||
        jobCompany.includes(term) ||
        reason.includes(term) ||
        details.includes(term)
      );
    });
  }, [reportsList, activeFilter, searchTerm]);

  const getReasonBadge = (reason: string) => {
    switch (reason) {
      case 'money_asked':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-red-100 text-red-700 text-xs font-black rounded-lg uppercase tracking-wider border border-red-200">
            <ShieldAlert size={12} /> Demande d'Argent
          </span>
        );
      case 'scam':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-amber-100 text-amber-700 text-xs font-black rounded-lg uppercase tracking-wider border border-amber-200">
            <AlertTriangle size={12} /> Fausse Offre / Arnaque
          </span>
        );
      case 'suspicious_behavior':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-orange-100 text-orange-700 text-xs font-black rounded-lg uppercase tracking-wider border border-orange-200">
            <AlertTriangle size={12} /> Comportement Suspect
          </span>
        );
      case 'harassment':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-purple-100 text-purple-700 text-xs font-black rounded-lg uppercase tracking-wider border border-purple-200">
            <AlertCircle size={12} /> Harcèlement / Propos
          </span>
        );
      case 'false_profile':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-rose-100 text-rose-700 text-xs font-black rounded-lg uppercase tracking-wider border border-rose-200">
            <UserX size={12} /> Faux Profil
          </span>
        );
      default:
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-slate-100 text-slate-700 text-xs font-black rounded-lg uppercase tracking-wider border border-slate-200">
            <AlertTriangle size={12} /> Autre Motif
          </span>
        );
    }
  };

  const getReasonDescription = (reason: string) => {
    switch (reason) {
      case 'money_asked':
        return "Demande d'argent, de frais de dossier ou de formation non autorisés.";
      case 'scam':
        return "Suspicion d'arnaque, d'extorsion ou de fausse annonce d'emploi.";
      case 'suspicious_behavior':
        return "Comportement inapproprié ou suspect signalé par un utilisateur.";
      case 'harassment':
        return "Harcèlement, propos irrespectueux ou abusifs dans les échanges.";
      case 'false_profile':
        return "Fausse identité ou fausses informations transmises.";
      default:
        return "Comportement suspect ou problème signalé par un utilisateur.";
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Metrics Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <button
          onClick={() => setActiveFilter('all')}
          className={`p-4 rounded-2xl border transition-all text-left flex justify-between items-center ${
            activeFilter === 'all'
              ? 'bg-slate-900 text-white border-slate-900 shadow-md'
              : 'bg-white text-slate-900 border-slate-200 hover:border-slate-300'
          }`}
        >
          <div>
            <p className={`text-[10px] font-black uppercase tracking-wider ${activeFilter === 'all' ? 'text-slate-400' : 'text-slate-500'}`}>
              Tous Signalements
            </p>
            <h4 className="text-2xl font-black mt-1">{totalCount}</h4>
          </div>
          <ShieldAlert className={activeFilter === 'all' ? 'text-white/30' : 'text-slate-300'} size={28} />
        </button>

        <button
          onClick={() => setActiveFilter('recruiters')}
          className={`p-4 rounded-2xl border transition-all text-left flex justify-between items-center ${
            activeFilter === 'recruiters'
              ? 'bg-purple-900 text-white border-purple-900 shadow-md'
              : 'bg-white text-slate-900 border-slate-200 hover:border-purple-300'
          }`}
        >
          <div>
            <p className={`text-[10px] font-black uppercase tracking-wider ${activeFilter === 'recruiters' ? 'text-purple-300' : 'text-purple-600'}`}>
              Recruteurs Signalés
            </p>
            <h4 className="text-2xl font-black mt-1">{recruiterCount}</h4>
          </div>
          <Building2 className={activeFilter === 'recruiters' ? 'text-white/30' : 'text-purple-300'} size={28} />
        </button>

        <button
          onClick={() => setActiveFilter('candidates')}
          className={`p-4 rounded-2xl border transition-all text-left flex justify-between items-center ${
            activeFilter === 'candidates'
              ? 'bg-orange-900 text-white border-orange-900 shadow-md'
              : 'bg-white text-slate-900 border-slate-200 hover:border-orange-300'
          }`}
        >
          <div>
            <p className={`text-[10px] font-black uppercase tracking-wider ${activeFilter === 'candidates' ? 'text-orange-300' : 'text-orange-600'}`}>
              Candidats Signalés
            </p>
            <h4 className="text-2xl font-black mt-1">{candidateCount}</h4>
          </div>
          <UserX className={activeFilter === 'candidates' ? 'text-white/30' : 'text-orange-300'} size={28} />
        </button>

        <button
          onClick={() => setActiveFilter('jobs')}
          className={`p-4 rounded-2xl border transition-all text-left flex justify-between items-center ${
            activeFilter === 'jobs'
              ? 'bg-red-900 text-white border-red-900 shadow-md'
              : 'bg-white text-slate-900 border-slate-200 hover:border-red-300'
          }`}
        >
          <div>
            <p className={`text-[10px] font-black uppercase tracking-wider ${activeFilter === 'jobs' ? 'text-red-300' : 'text-red-600'}`}>
              Offres Signalées
            </p>
            <h4 className="text-2xl font-black mt-1">{jobCount}</h4>
          </div>
          <Briefcase className={activeFilter === 'jobs' ? 'text-white/30' : 'text-red-300'} size={28} />
        </button>
      </div>

      {/* Header and Refresh */}
      <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h3 className="text-lg font-black text-slate-900 uppercase tracking-tight flex items-center gap-2">
              <ShieldAlert className="text-red-500" size={22} />
              Signalements d'Abus & Modération
            </h3>
            <p className="text-xs text-slate-500 font-medium mt-1">
              Consultez et modérez la liste des candidats et recruteurs signalés sur la plateforme.
            </p>
          </div>
          <button 
            onClick={fetchReports}
            disabled={isLoading}
            className="p-3 text-slate-500 hover:text-primary hover:bg-primary/5 rounded-xl border border-slate-200 transition-all flex items-center gap-2 self-end sm:self-auto"
            title="Actualiser"
          >
            {isLoading ? <RefreshCw size={20} className="animate-spin" /> : <RefreshCw size={20} />}
            <span className="text-xs font-bold uppercase tracking-wider hidden md:inline">Actualiser</span>
          </button>
        </div>

        {/* Filter Sub-Tabs & Search Bar */}
        <div className="flex flex-col lg:flex-row justify-between gap-4 pt-2 border-t border-slate-100">
          {/* Sub-tabs */}
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setActiveFilter('all')}
              className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all ${
                activeFilter === 'all'
                  ? 'bg-slate-900 text-white shadow-sm'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              Tous ({totalCount})
            </button>

            <button
              onClick={() => setActiveFilter('recruiters')}
              className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 ${
                activeFilter === 'recruiters'
                  ? 'bg-purple-700 text-white shadow-sm'
                  : 'bg-purple-50 text-purple-700 hover:bg-purple-100'
              }`}
            >
              <Building2 size={14} />
              Recruteurs ({recruiterCount})
            </button>

            <button
              onClick={() => setActiveFilter('candidates')}
              className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 ${
                activeFilter === 'candidates'
                  ? 'bg-orange-600 text-white shadow-sm'
                  : 'bg-orange-50 text-orange-700 hover:bg-orange-100'
              }`}
            >
              <UserX size={14} />
              Candidats ({candidateCount})
            </button>

            <button
              onClick={() => setActiveFilter('jobs')}
              className={`px-3.5 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 ${
                activeFilter === 'jobs'
                  ? 'bg-red-600 text-white shadow-sm'
                  : 'bg-red-50 text-red-700 hover:bg-red-100'
              }`}
            >
              <Briefcase size={14} />
              Offres ({jobCount})
            </button>
          </div>

          {/* Search Bar */}
          <div className="relative min-w-[240px]">
            <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              placeholder="Rechercher nom, entreprise, téléphone..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-900 focus:outline-none focus:border-primary transition-all"
            />
          </div>
        </div>
      </div>

      {/* Reports Grid */}
      {filteredReports.length > 0 ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {filteredReports.map((report) => {
            const isRecruiter = report.reported_profile?.is_recruiter === true;

            return (
              <div 
                key={report.id} 
                className="bg-white rounded-3xl border-2 border-slate-200 hover:border-slate-400 transition-all shadow-sm overflow-hidden flex flex-col group"
              >
                {/* Top Warning header */}
                <div className="bg-red-50/50 p-4 border-b border-slate-100 flex justify-between items-center flex-wrap gap-2">
                  <div className="flex items-center gap-2">
                    {getReasonBadge(report.reason)}
                  </div>
                  <div className="flex items-center gap-2 text-slate-400 font-mono text-[10px]">
                    <Calendar size={12} />
                    {new Date(report.created_at).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}
                  </div>
                </div>

                {/* Content */}
                <div className="p-6 space-y-4 flex-1">
                  {/* Reason description */}
                  <p className="text-sm font-bold text-slate-800 italic">
                    "{getReasonDescription(report.reason)}"
                  </p>

                  {/* Additional details */}
                  {report.details && (
                    <div className="p-3.5 bg-slate-50 rounded-2xl border border-slate-100 flex gap-2">
                      <MessageSquare size={16} className="text-slate-400 shrink-0 mt-0.5" />
                      <p className="text-xs text-slate-600 font-medium leading-relaxed">
                        {report.details}
                      </p>
                    </div>
                  )}

                  {/* Targeted Profile: Recruiter or Candidate */}
                  {report.reported_profile && (
                    <div className={`p-4 rounded-2xl border space-y-2.5 ${
                      isRecruiter 
                        ? 'bg-purple-50/60 border-purple-200' 
                        : 'bg-orange-50/60 border-orange-200'
                    }`}>
                      <div className="flex justify-between items-center">
                        <p className={`text-[10px] font-black uppercase tracking-widest flex items-center gap-1.5 ${
                          isRecruiter ? 'text-purple-700' : 'text-orange-700'
                        }`}>
                          {isRecruiter ? (
                            <>
                              <Building2 size={14} /> RECRUTEUR SIGNALÉ
                            </>
                          ) : (
                            <>
                              <UserX size={14} /> CANDIDAT SIGNALÉ
                            </>
                          )}
                        </p>

                        {report.reported_profile.is_blocked ? (
                          <span className="px-2.5 py-0.5 bg-red-600 text-white font-black text-[10px] rounded-full uppercase tracking-wider">
                            Bloqué 🔴
                          </span>
                        ) : (
                          <span className="px-2.5 py-0.5 bg-emerald-100 text-emerald-800 border border-emerald-300 font-black text-[10px] rounded-full uppercase tracking-wider">
                            Actif 🟢
                          </span>
                        )}
                      </div>

                      <div>
                        <p className="text-sm font-black text-slate-900">
                          {isRecruiter 
                            ? (report.reported_profile.company_name || report.reported_profile.full_name || 'Entreprise Recruteur')
                            : (report.reported_profile.full_name || 'Candidat')
                          }
                        </p>
                        <p className="text-xs text-slate-600 font-semibold mt-0.5">
                          Nom: <strong>{report.reported_profile.full_name || 'Non renseigné'}</strong> 
                          {report.reported_profile.phone_number ? ` • Tél: ${report.reported_profile.phone_number}` : ''}
                        </p>
                      </div>
                    </div>
                  )}

                  {/* Targeted Job */}
                  {report.jobs && (
                    <div className="p-4 bg-slate-50 border border-slate-200 rounded-2xl space-y-2">
                      <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest flex items-center gap-1">
                        <Briefcase size={12} /> OFFRE D'EMPLOI SIGNALÉE
                      </p>
                      <div>
                        <p className="text-sm font-black text-slate-900 group-hover:text-primary transition-all">
                          {report.jobs.job_title}
                        </p>
                        <p className="text-xs text-slate-500 font-bold uppercase mt-0.5">
                          {report.jobs.company_name} • {report.jobs.location}
                        </p>
                      </div>
                    </div>
                  )}

                  {/* Reporter */}
                  <div className="flex items-center gap-2 text-xs text-slate-500 font-medium pt-2">
                    <User size={14} className="text-slate-400" />
                    <span>Signalé par : <strong className="text-slate-700">{report.profiles?.full_name || 'Utilisateur anonyme'}</strong></span>
                  </div>
                </div>

                {/* Actions Footer */}
                <div className="p-4 bg-slate-50/50 border-t border-slate-100 flex flex-wrap gap-3">
                  {report.reported_profile && handleToggleBlockUser && (
                    <button
                      onClick={() => handleToggleBlockUser!(report.reported_profile!.id, report.reported_profile!.is_blocked)}
                      disabled={isLoading}
                      className={`flex-1 py-3 rounded-xl font-black text-xs uppercase tracking-widest transition-all flex items-center justify-center gap-2 ${
                        report.reported_profile.is_blocked
                          ? 'bg-emerald-600 text-white hover:bg-emerald-700'
                          : 'bg-red-600 text-white hover:bg-red-700 shadow-md shadow-red-200'
                      }`}
                    >
                      {report.reported_profile.is_blocked ? (
                        <>
                          <UserCheck size={14} /> Débloquer {isRecruiter ? 'Recruteur' : 'Candidat'}
                        </>
                      ) : (
                        <>
                          <UserX size={14} /> Bloquer {isRecruiter ? 'Recruteur' : 'Candidat'}
                        </>
                      )}
                    </button>
                  )}

                  {report.jobs && (
                    <button 
                      onClick={() => handleDeleteJob(report.jobs!.id)}
                      disabled={isLoading}
                      className="flex-1 py-3 bg-red-500 text-white rounded-xl font-black text-xs uppercase tracking-widest shadow-md shadow-red-200 hover:bg-red-600 transition-all flex items-center justify-center gap-2"
                    >
                      <Trash2 size={14} />
                      Supprimer l'offre
                    </button>
                  )}
                  
                  <button 
                    onClick={() => handleDismissReport(report.id)}
                    disabled={isLoading}
                    className="flex-1 py-3 bg-white text-slate-700 border-2 border-slate-200 rounded-xl font-black text-xs uppercase tracking-widest hover:bg-slate-100 transition-all flex items-center justify-center gap-2"
                  >
                    <Check size={14} />
                    Classer sans suite
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="bg-white p-20 rounded-3xl border border-slate-200 shadow-sm text-center">
          <ShieldAlert size={48} className="mx-auto text-slate-200 mb-4" />
          <p className="text-slate-400 font-bold uppercase tracking-widest text-sm">
            {searchTerm ? "Aucun signalement ne correspond à votre recherche" : "Aucun signalement dans cette catégorie"}
          </p>
          <p className="text-xs text-slate-400 mt-2">La plateforme est saine et sécurisée. Bon travail !</p>
        </div>
      )}
    </div>
  );
};

export default ReportsTab;
