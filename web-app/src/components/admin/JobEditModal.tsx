import React from 'react';
import { X, Pencil, RefreshCw } from 'lucide-react';

interface JobEditModalProps {
  editingJob: any;
  setEditingJob: (job: any) => void;
  isLoading: boolean;
  handleUpdateJob: (e: React.FormEvent) => Promise<void>;
}

const JobEditModal: React.FC<JobEditModalProps> = ({
  editingJob,
  setEditingJob,
  isLoading,
  handleUpdateJob
}) => {
  if (!editingJob) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="bg-white w-full max-w-2xl rounded-3xl shadow-2xl overflow-hidden animate-in zoom-in-95 duration-300 border border-white/20">
        <div className="bg-primary/5 p-6 border-b border-primary/10 flex justify-between items-center">
          <div>
            <h2 className="text-xl font-black text-slate-900 flex items-center gap-2 uppercase tracking-tight">
              <Pencil size={20} className="text-primary" /> Modifier l'Offre
            </h2>
            <p className="text-xs text-slate-500 font-medium mt-1">ID: {editingJob.id.substring(0, 8)}...</p>
          </div>
          <button 
            onClick={() => setEditingJob(null)}
            className="p-2 hover:bg-white rounded-xl transition-colors text-slate-400 hover:text-slate-600"
          >
            <X size={24} />
          </button>
        </div>
        
        <form onSubmit={handleUpdateJob} className="p-6 md:p-8 space-y-6 max-h-[70vh] overflow-y-auto custom-scrollbar">
          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Titre de l'Offre</label>
              <input 
                type="text" 
                value={editingJob.job_title} 
                onChange={e => setEditingJob({...editingJob, job_title: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Lieu (Ville)</label>
              <input 
                type="text" 
                value={editingJob.location} 
                onChange={e => setEditingJob({...editingJob, location: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Niveau (Diplôme)</label>
              <input 
                type="text" 
                value={editingJob.required_level || ''} 
                onChange={e => setEditingJob({...editingJob, required_level: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Date Limite</label>
              <input 
                type="text" 
                value={editingJob.deadline || ''} 
                onChange={e => setEditingJob({...editingJob, deadline: e.target.value})}
                placeholder="JJ/MM/AAAA"
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
          </div>

          <div className="space-y-2">
            <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Résumé / Description (JSON: summary)</label>
            <textarea 
              rows={4} 
              value={editingJob.description} 
              onChange={e => setEditingJob({...editingJob, description: e.target.value})}
              className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-medium text-slate-600 resize-none"
            ></textarea>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Mots-clés / Tags (séparés par virgule)</label>
              <input 
                type="text" 
                value={Array.isArray(editingJob.tags) ? editingJob.tags.join(', ') : editingJob.tags} 
                onChange={e => setEditingJob({...editingJob, tags: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">E-mail de contact</label>
              <input 
                type="email" 
                value={editingJob.contact_email || ''} 
                onChange={e => setEditingJob({...editingJob, contact_email: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-medium text-slate-700"
              />
            </div>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Contact WhatsApp (JSON: contact)</label>
              <input 
                type="text" 
                value={editingJob.whatsapp_number || ''} 
                onChange={e => setEditingJob({...editingJob, whatsapp_number: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Objet / Instructions (JSON: objet)</label>
              <input 
                type="text" 
                value={editingJob.application_instructions || ''} 
                onChange={e => setEditingJob({...editingJob, application_instructions: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">URL Source (JSON: urls)</label>
              <input 
                type="text" 
                value={editingJob.source_url || editingJob.application_link || ''} 
                onChange={e => setEditingJob({...editingJob, source_url: e.target.value, application_link: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-medium text-slate-700"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Salaire</label>
              <input 
                type="text" 
                value={editingJob.salary_range || ''} 
                onChange={e => setEditingJob({...editingJob, salary_range: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-black uppercase tracking-widest text-slate-400 ml-1">Nom de l'Entreprise</label>
              <input 
                type="text" 
                value={editingJob.company_name} 
                onChange={e => setEditingJob({...editingJob, company_name: e.target.value})}
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-2xl focus:border-primary outline-none transition-all font-bold text-slate-700"
              />
            </div>
          </div>

          <div className="flex gap-4 pt-4">
            <button 
              type="button"
              onClick={() => setEditingJob(null)}
              className="flex-1 py-4 bg-slate-100 text-slate-600 font-black rounded-2xl hover:bg-slate-200 transition-all uppercase tracking-widest text-sm"
            >
              Annuler
            </button>
            <button 
              type="submit"
              disabled={isLoading}
              className="flex-[2] py-4 bg-primary text-white font-black rounded-2xl border-b-4 border-slate-900 active:border-b-0 active:translate-y-1 transition-all flex items-center justify-center gap-2 uppercase tracking-widest text-sm"
            >
              {isLoading ? <RefreshCw className="animate-spin" /> : 'Sauvegarder les modifications'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default JobEditModal;
