import React from 'react';
import { ShieldAlert, Trash2, Check, AlertTriangle, Calendar, User, Briefcase, RefreshCw, MessageSquare } from 'lucide-react';

interface ReportItem {
  id: string;
  reason: string;
  details: string | null;
  created_at: string;
  user_id: string;
  profiles: {
    full_name: string | null;
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
  fetchReports: () => Promise<void>;
}

const ReportsTab: React.FC<ReportsTabProps> = ({
  reportsList,
  isLoading,
  handleDeleteJob,
  handleDismissReport,
  fetchReports
}) => {
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
            <AlertTriangle size={12} /> Fausse Offre
          </span>
        );
      case 'suspicious_behavior':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-orange-100 text-orange-700 text-xs font-black rounded-lg uppercase tracking-wider border border-orange-200">
            <AlertTriangle size={12} /> Comportement Suspect
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
        return "Le recruteur a demandé des frais de dossier, de formation ou de l'argent.";
      case 'scam':
        return "L'offre d'emploi est suspectée d'être fausse ou mensongère.";
      case 'suspicious_behavior':
        return "Comportement inapproprié ou suspect signalé par le candidat.";
      default:
        return "Autre comportement suspect signalé.";
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Header and refresh */}
      <div className="flex justify-between items-center bg-white p-6 rounded-3xl border border-slate-200 shadow-sm">
        <div>
          <h3 className="text-lg font-black text-slate-900 uppercase tracking-tight flex items-center gap-2">
            <ShieldAlert className="text-red-500" size={22} />
            Signalements d'Abus
          </h3>
          <p className="text-xs text-slate-500 font-medium mt-1">
            Modérez les offres d'emploi signalées par les candidats pour suspicion de fraude ou d'arnaque.
          </p>
        </div>
        <button 
          onClick={fetchReports}
          disabled={isLoading}
          className="p-3 text-slate-400 hover:text-primary hover:bg-primary/5 rounded-xl border border-slate-100 transition-all flex items-center gap-2"
          title="Actualiser"
        >
          {isLoading ? <RefreshCw size={20} className="animate-spin" /> : <RefreshCw size={20} />}
        </button>
      </div>

      {/* Reports Grid */}
      {reportsList.length > 0 ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {reportsList.map((report) => (
            <div 
              key={report.id} 
              className="bg-white rounded-3xl border-2 border-slate-200 hover:border-red-400 transition-all shadow-sm overflow-hidden flex flex-col group"
            >
              {/* Top Warning header */}
              <div className="bg-red-50/50 p-4 border-b border-slate-100 flex justify-between items-center">
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

                {/* Targeted Job */}
                {report.jobs ? (
                  <div className="p-4 bg-slate-50 border border-slate-100 rounded-2xl space-y-2">
                    <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest flex items-center gap-1">
                      <Briefcase size={12} /> Offre Signalée
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
                ) : (
                  <div className="p-4 bg-slate-50 border border-slate-100 rounded-2xl text-slate-400 text-xs italic">
                    Offre d'emploi déjà supprimée.
                  </div>
                )}

                {/* Reporter */}
                <div className="flex items-center gap-2 text-xs text-slate-500 font-medium pt-2">
                  <User size={14} className="text-slate-400" />
                  <span>Signalé par : <strong className="text-slate-700">{report.profiles?.full_name || 'Candidat anonyme'}</strong></span>
                </div>
              </div>

              {/* Actions Footer */}
              <div className="p-4 bg-slate-50/50 border-t border-slate-100 flex gap-3">
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
          ))}
        </div>
      ) : (
        <div className="bg-white p-20 rounded-3xl border border-slate-200 shadow-sm text-center">
          <ShieldAlert size={48} className="mx-auto text-slate-200 mb-4" />
          <p className="text-slate-400 font-bold uppercase tracking-widest text-sm">Aucun signalement d'abus en attente</p>
          <p className="text-xs text-slate-400 mt-2">La plateforme est saine et sécurisée. Bon travail !</p>
        </div>
      )}
    </div>
  );
};

export default ReportsTab;
