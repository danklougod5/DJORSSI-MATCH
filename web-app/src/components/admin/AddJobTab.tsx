import React from 'react';
import { FileText, LayoutGrid, CheckCircle2, AlertCircle, RefreshCw, Plus } from 'lucide-react';

interface AddJobTabProps {
  isBulkMode: boolean;
  setIsBulkMode: (mode: boolean) => void;
  successMessage: string;
  errorMessage: string;
  isLoading: boolean;
  handleAddSingleJob: (e: React.FormEvent<HTMLFormElement>) => Promise<void>;
  handleAddBulkJobs: (e: React.FormEvent<HTMLFormElement>) => Promise<void>;
  handleFileUpload: (e: React.ChangeEvent<HTMLInputElement>) => void;
}

const AddJobTab: React.FC<AddJobTabProps> = ({
  isBulkMode,
  setIsBulkMode,
  successMessage,
  errorMessage,
  isLoading,
  handleAddSingleJob,
  handleAddBulkJobs,
  handleFileUpload
}) => {
  return (
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
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Titre de l'Offre</label>
                <input name="title" required placeholder="Ex: Développeur React" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Lieu (Ville)</label>
                <input name="lieu" placeholder="Ex: Abidjan" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
            </div>

            <div className="grid md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Niveau (Diplôme)</label>
                <input name="niveau" placeholder="Ex: BAC+3" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Date Limite</label>
                <input name="deadline" placeholder="JJ/MM/AAAA" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-black uppercase tracking-tight text-slate-500">Résumé / Description (JSON: summary)</label>
              <textarea name="summary" rows={4} placeholder="Missions et profil recherché..." className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium resize-none"></textarea>
            </div>

            <div className="grid md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Mots-clés / Tags (séparés par virgule)</label>
                <input name="tags" placeholder="Informatique, Frontend, React" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">E-mail de contact</label>
                <input name="email" placeholder="rh@entreprise.com" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
            </div>

            <div className="grid md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Contact WhatsApp (JSON: contact)</label>
                <input name="contact" placeholder="0707..." className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Objet / Instructions (JSON: objet)</label>
                <input name="objet" placeholder="Candidature pour..." className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
            </div>

            <div className="grid md:grid-cols-3 gap-6">
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">URL Source (JSON: urls)</label>
                <input name="urls" placeholder="https://..." className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Salaire</label>
                <input name="salary_range" placeholder="Ex: 500k" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-black uppercase tracking-tight text-slate-500">Nom de l'Entreprise</label>
                <input name="company_name" placeholder="Ex: Orange CI" className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-medium" />
              </div>
            </div>

            <button 
              type="submit"
              disabled={isLoading}
              className="w-full bg-primary text-white font-black py-4 rounded-xl border-b-4 border-slate-900 active:border-b-0 active:translate-y-1 transition-all flex items-center justify-center gap-2 uppercase tracking-widest disabled:opacity-50"
            >
              {isLoading ? <RefreshCw className="animate-spin" /> : <Plus />} Ajouter l'offre conforme JSON
            </button>
          </form>
        </div>
      ) : (
        <div className="bg-white p-6 md:p-8 rounded-2xl border border-slate-200 shadow-sm space-y-6">
          <div className="bg-primary/5 p-4 rounded-xl border-l-4 border-primary">
            <p className="text-sm font-bold text-slate-800">Format accepté :</p>
            <p className="text-xs text-slate-600 mt-1">Collez un tableau JSON d'offres (Format extraction5.json) OU une liste formatée (Titre - Entreprise...)</p>
          </div>

          <form onSubmit={handleAddBulkJobs} className="space-y-6">
              <div className="flex items-center gap-4">
                <label className="bg-primary/10 text-primary font-bold px-4 py-2 rounded-lg cursor-pointer hover:bg-primary/20 transition-colors">
                  Parcourir un fichier JSON
                  <input type="file" accept=".json,.txt" className="hidden" onChange={handleFileUpload} />
                </label>
                <span className="text-sm text-slate-500">ou collez le texte ci-dessous</span>
              </div>
            <div className="space-y-2">
              <label className="text-sm font-black uppercase tracking-tight text-slate-500">Données Massives</label>
              <textarea 
                name="bulkText"
                id="bulkText"
                required
                rows={12} 
                placeholder='Collez ici le contenu de extraction.json avec la structure [{"title": "...", "company_name": "..."}] ...' 
                className="w-full px-4 py-3 bg-slate-50 border-2 border-slate-100 rounded-xl focus:border-primary outline-none transition-all font-mono text-sm resize-none"
              ></textarea>
            </div>

            <button 
              type="submit"
              disabled={isLoading}
              className="w-full bg-secondary text-white font-black py-4 rounded-xl border-b-4 border-slate-900 active:border-b-0 active:translate-y-1 transition-all flex items-center justify-center gap-2 uppercase tracking-widest disabled:opacity-50"
            >
              {isLoading ? <RefreshCw className="animate-spin" /> : <LayoutGrid />} Importer les offres
            </button>
          </form>
        </div>
      )}
    </div>
  );
};

export default AddJobTab;
