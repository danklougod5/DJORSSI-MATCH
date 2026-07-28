import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Briefcase,
  Building2,
  MapPin,
  GraduationCap,
  DollarSign,
  Calendar,
  Mail,
  Phone,
  AlertTriangle,
  Gavel,
  CheckCircle2,
  AlertCircle,
  RefreshCw,
  Search,
  X,
  ChevronLeft
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { formatLongDate } from '../lib/dateUtils';

const contractTypes = ['CDI', 'CDD', 'Stage', 'Alternance', 'Freelance', 'Intérim'];

const RecruiterPage: React.FC = () => {
  const navigate = useNavigate();

  // Form states
  const [formData, setFormData] = useState({
    company: '',
    title: '',
    location: '',
    level: '',
    salary: '',
    deadline: '',
    description: '',
    email: '',
    phone: '',
  });

  const [contractType, setContractType] = useState('CDI');
  const [requiresCoverLetter, setRequiresCoverLetter] = useState(false);
  const [isSalaryNonNegotiable, setIsSalaryNonNegotiable] = useState(false);
  
  // Loading & statuses
  const [isLoading, setIsLoading] = useState(false);
  const [submitStatus, setSubmitStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [errorMessage, setErrorMessage] = useState('');

  // Tags States
  const [availableTags, setAvailableTags] = useState<string[]>([]);
  const [selectedTags, setSelectedTags] = useState<Set<string>>(new Set());
  const [tagSearchQuery, setTagSearchQuery] = useState('');
  const [isLoadingTags, setIsLoadingTags] = useState(true);

  useEffect(() => {
    loadAvailableTags();
  }, []);

  const loadAvailableTags = async () => {
    setIsLoadingTags(true);
    try {
      const { data, error } = await supabase
        .from('jobs')
        .select('tags')
        .eq('is_approved', true)
        .limit(100);

      if (error) throw error;

      const rawTags: string[] = [];
      if (data) {
        data.forEach((row: any) => {
          if (row.tags && Array.isArray(row.tags)) {
            rawTags.push(...row.tags);
          }
        });
      }

      // Deduplicate and filter out common placeholder tags
      const uniqueTags = Array.from(new Set(rawTags))
        .filter(t => t && t.trim() !== '' && t.toLowerCase() !== 'urgent' && t.toLowerCase() !== 'recrutement');

      setAvailableTags(uniqueTags);
    } catch (err) {
      console.error('Error fetching tags:', err);
    } finally {
      setIsLoadingTags(false);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    if (name === 'salary') {
      const cleanValue = value.replace(/\D/g, '');
      setFormData((prev) => ({ ...prev, [name]: cleanValue }));
    } else {
      setFormData((prev) => ({ ...prev, [name]: value }));
    }
  };

  const handleTagToggle = (tag: string) => {
    setSelectedTags((prev) => {
      const next = new Set(prev);
      if (next.has(tag)) {
        next.delete(tag);
      } else {
        next.add(tag);
      }
      return next;
    });
  };

  const handleRemoveTag = (tag: string) => {
    setSelectedTags((prev) => {
      const next = new Set(prev);
      next.delete(tag);
      return next;
    });
  };

  const handleJobSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (selectedTags.size === 0) {
      setSubmitStatus('error');
      setErrorMessage('Veuillez sélectionner au moins un tag de secteur ou compétence.');
      return;
    }

    if (!formData.email && !formData.phone) {
      setSubmitStatus('error');
      setErrorMessage('Veuillez renseigner au moins un moyen de contact (e-mail ou numéro WhatsApp).');
      return;
    }

    setIsLoading(true);
    setSubmitStatus('idle');
    setErrorMessage('');

    try {
      const cleanPhone = (phoneStr: string) => {
        if (!phoneStr) return '';
        let cleaned = phoneStr.replace(/\s+/g, '').replace(/[^\d+]/g, '');
        if (cleaned.startsWith('0') && cleaned.length === 10) {
          cleaned = '+225' + cleaned.substring(1);
        }
        return cleaned;
      };

      const randomSuffix = Math.floor(100000 + Math.random() * 900000).toString();
      const uniqueSourceUrl = `recruiter_post_${Date.now()}_${randomSuffix}`;

      const tags = Array.from(selectedTags);
      if (!tags.includes(contractType)) {
        tags.push(contractType);
      }

      let formattedSalary = formData.salary.trim();
      if (isSalaryNonNegotiable) {
        if (formattedSalary) {
          if (!formattedSalary.toLowerCase().includes('non négociable')) {
            formattedSalary += ' (Non négociable)';
          }
        } else {
          formattedSalary = 'Non négociable';
        }
      }

      const rawData = {
        company_name: formData.company.trim(),
        job_title: formData.title.trim(),
        location: formData.location.trim(),
        required_level: formData.level.trim(),
        salary_range: formattedSalary,
        contact_email: formData.email.trim(),
        whatsapp_number: formData.phone.trim(),
        description: formData.description.trim(),
        tags: tags,
        contract_type: contractType,
        requires_cover_letter: requiresCoverLetter,
        cover_letter_instructions: null,
        deadline: formData.deadline.trim() || null,
      };

      const jobData = {
        company_name: rawData.company_name,
        job_title: rawData.job_title,
        location: rawData.location || "Abidjan",
        required_level: rawData.required_level,
        salary_range: rawData.salary_range || null,
        contact_email: rawData.contact_email || null,
        whatsapp_number: cleanPhone(rawData.whatsapp_number),
        description: rawData.description,
        tags: tags,
        requires_cover_letter: requiresCoverLetter,
        cover_letter_instructions: null,
        deadline: rawData.deadline,
        is_ai_verified: false, // Scammers prevention
        is_approved: false, // Must be approved by admin
        source_url: uniqueSourceUrl,
        created_at: new Date().toISOString(),
        raw_data: rawData,
      };

      const { error } = await supabase.from('jobs').insert([jobData]);
      if (error) throw error;

      setSubmitStatus('success');
      setIsSalaryNonNegotiable(false);
      setFormData({
        company: '',
        title: '',
        location: '',
        level: '',
        salary: '',
        deadline: '',
        description: '',
        email: '',
        phone: '',
      });
      setSelectedTags(new Set());
    } catch (err: any) {
      console.error('Error submitting recruiter job:', err);
      setSubmitStatus('error');
      setErrorMessage(err.message || 'Une erreur est survenue lors de la publication.');
    } finally {
      setIsLoading(false);
    }
  };

  const filteredTags = tagSearchQuery.trim() === ''
    ? availableTags
    : availableTags.filter((t) => t.toLowerCase().includes(tagSearchQuery.toLowerCase()));

  return (
    <div className="min-h-screen bg-background selection:bg-accent selection:text-black pb-20">
      {/* Navigation Header */}
      <nav className="fixed top-0 w-full z-50 bg-white border-b-4 border-black">
        <div className="max-w-7xl mx-auto px-4 md:px-6 h-20 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              onClick={() => navigate('/')}
              className="p-2 border-2 border-black bg-slate-50 hover:bg-slate-100 rounded-lg shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:translate-x-[2px] active:translate-y-[2px] active:shadow-none transition-all flex items-center gap-1 font-black text-xs uppercase"
            >
              <ChevronLeft size={16} /> Retour
            </button>
            <span className="font-heading text-lg font-black uppercase tracking-tighter">
              Djorssi<span className="text-primary">-Match</span>
            </span>
          </div>
          <span className="font-heading text-sm font-black uppercase bg-primary text-white border-2 border-black px-4 py-1.5 shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] rotate-2 hidden sm:inline-block">
            Espace Recruteurs
          </span>
        </div>
      </nav>

      {/* Main Content */}
      <div className="max-w-3xl mx-auto pt-32 px-4 md:px-6">
        {submitStatus === 'success' ? (
          /* SUCCESS VIEW */
          <div className="border-4 border-black bg-white p-8 md:p-12 shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] rounded-2xl text-center space-y-8 animate-in zoom-in duration-300">
            <div className="w-20 h-20 bg-green-500 border-4 border-black rounded-full flex items-center justify-center mx-auto shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
              <CheckCircle2 className="text-white" size={44} />
            </div>
            
            <div className="space-y-3">
              <h2 className="text-3xl font-heading font-black uppercase">Offre soumise avec succès !</h2>
              <p className="font-bold text-slate-500">
                Merci d'utiliser Djorssi-Match pour vos recrutements.
              </p>
            </div>

            <div className="bg-amber-50 border-2 border-amber-200 p-6 rounded-xl text-left flex gap-4">
              <AlertTriangle className="text-amber-600 shrink-0 mt-0.5" size={24} />
              <div className="space-y-1">
                <p className="font-black text-amber-900 uppercase text-sm tracking-wide">Validation en cours</p>
                <p className="text-xs font-bold text-amber-700 leading-relaxed">
                  Votre offre est en attente de vérification par notre équipe administrative. Elle sera approuvée et publiée en ligne sur l'application mobile sous 24h maximum.
                </p>
              </div>
            </div>

            <div className="flex flex-col sm:flex-row gap-4 pt-4 justify-center">
              <button
                onClick={() => setSubmitStatus('idle')}
                className="neo-brutal-btn-secondary py-4 px-8 text-base font-black uppercase"
              >
                Déposer une autre offre
              </button>
              <button
                onClick={() => navigate('/')}
                className="neo-brutal-btn py-4 px-8 text-base font-black uppercase"
              >
                Retour à l'accueil
              </button>
            </div>
          </div>
        ) : (
          /* FORM VIEW */
          <div className="space-y-8">
            {/* Anti-Fraud Banner */}
            <div className="bg-amber-100 border-4 border-black p-5 rounded-2xl flex gap-4 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
              <AlertTriangle className="text-amber-600 shrink-0 mt-0.5" size={24} />
              <div className="space-y-1">
                <p className="font-black text-amber-900 uppercase text-sm tracking-wide">Rappel Anti-Fraude Important</p>
                <p className="text-xs font-bold text-amber-700 leading-relaxed">
                  Tous les recrutements sur Djorssi-Match sont 100% gratuits pour les candidats. Tout frais de dossier, formation payante obligatoire ou demande d'argent pour passer un entretien conduira au bannissement immédiat de votre entreprise.
                </p>
              </div>
            </div>

            <div className="bg-white border-4 border-black p-6 md:p-10 shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] rounded-2xl">
              <h1 className="text-3xl font-heading font-black uppercase mb-8 border-b-4 border-black pb-4 flex items-center gap-2">
                <Briefcase className="text-primary" size={28} /> Publier un job
              </h1>

              {submitStatus === 'error' && (
                <div className="bg-red-50 border-2 border-red-500/20 p-4 rounded-xl flex items-center gap-3 text-red-700 font-bold mb-6">
                  <AlertCircle className="shrink-0" /> {errorMessage}
                </div>
              )}

              <form onSubmit={handleJobSubmit} className="space-y-8">
                {/* Section : Entreprise */}
                <div className="space-y-4">
                  <h3 className="text-xs font-black uppercase tracking-wider text-primary border-l-4 border-primary pl-2">
                    Informations de l'entreprise
                  </h3>
                  <div className="relative">
                    <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                      Nom de l'entreprise *
                    </label>
                    <div className="relative">
                      <Building2 className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                      <input
                        type="text"
                        name="company"
                        required
                        value={formData.company}
                        onChange={handleInputChange}
                        placeholder="Ex: Orange CI, Boutique Ivoire..."
                        className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                      />
                    </div>
                  </div>
                </div>

                {/* Section : Détails du poste */}
                <div className="space-y-5">
                  <h3 className="text-xs font-black uppercase tracking-wider text-primary border-l-4 border-primary pl-2">
                    Détails du poste
                  </h3>

                  <div className="grid md:grid-cols-2 gap-5">
                    <div>
                      <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                        Titre du poste *
                      </label>
                      <div className="relative">
                        <Briefcase className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                          type="text"
                          name="title"
                          required
                          value={formData.title}
                          onChange={handleInputChange}
                          placeholder="Ex: Chauffeur de Taxi, Secrétaire..."
                          className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                        Type de contrat *
                      </label>
                      <select
                        value={contractType}
                        onChange={(e) => setContractType(e.target.value)}
                        className="w-full px-3.5 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold text-black cursor-pointer"
                      >
                        {contractTypes.map((type) => (
                          <option key={type} value={type}>
                            {type}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>

                  <div className="grid md:grid-cols-2 gap-5">
                    <div>
                      <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                        Ville / Localisation *
                      </label>
                      <div className="relative">
                        <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                          type="text"
                          name="location"
                          required
                          value={formData.location}
                          onChange={handleInputChange}
                          placeholder="Ex: Abidjan - Cocody, Bouaké..."
                          className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                        Niveau requis *
                      </label>
                      <div className="relative">
                        <GraduationCap className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                          type="text"
                          name="level"
                          required
                          value={formData.level}
                          onChange={handleInputChange}
                          placeholder="Ex: BAC, BAC+2, CAP, Sans diplôme..."
                          className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                        />
                      </div>
                    </div>
                  </div>

                  <div className="grid md:grid-cols-2 gap-5">
                    <div>
                      <div className="flex items-center justify-between mb-1.5">
                        <label className="block text-xs font-black uppercase tracking-wider text-black">
                          Salaire / Rémunération
                        </label>
                        <label className="flex items-center gap-1.5 cursor-pointer text-xs font-bold text-slate-700 hover:text-black transition-colors select-none">
                          <input
                            type="checkbox"
                            checked={isSalaryNonNegotiable}
                            onChange={(e) => setIsSalaryNonNegotiable(e.target.checked)}
                            className="w-4 h-4 accent-primary rounded cursor-pointer"
                          />
                          <span>Non négociable</span>
                        </label>
                      </div>
                      <div className="relative">
                        <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                          type="text"
                          name="salary"
                          value={formData.salary}
                          onChange={handleInputChange}
                          placeholder={isSalaryNonNegotiable ? "Ex: 150000 (Non négociable)" : "Ex: 150000 (Chiffres uniquement)"}
                          className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                        Date limite *
                      </label>
                      <div className="relative">
                        <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                          type="date"
                          name="deadline"
                          required
                          min={new Date().toISOString().split('T')[0]}
                          value={formData.deadline}
                          onChange={handleInputChange}
                          className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                        />
                      </div>
                      <p className="text-[10px] text-slate-500 font-bold mt-1">
                        Sélectionnez la date limite de validité de cette offre.
                      </p>
                      {formData.deadline && (
                        <p className="text-xs text-[#10B981] font-extrabold mt-1.5 flex items-center gap-1.5 bg-[#10B981]/5 px-2.5 py-1.5 border border-[#10B981]/20 rounded-lg w-fit">
                          <CheckCircle2 size={14} className="shrink-0" />
                          Date limite : <span className="capitalize">{formatLongDate(formData.deadline)}</span>
                        </p>
                      )}
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                      Description du poste & prérequis *
                    </label>
                    <textarea
                      name="description"
                      required
                      rows={5}
                      value={formData.description}
                      onChange={handleInputChange}
                      placeholder="Décrivez en détail les tâches quotidiennes et les compétences attendues du candidat..."
                      className="w-full px-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black resize-none"
                    ></textarea>
                  </div>
                </div>

                {/* Section : Secteurs / Tags */}
                <div className="space-y-4">
                  <h3 className="text-xs font-black uppercase tracking-wider text-primary border-l-4 border-primary pl-2">
                    Secteurs & Compétences *
                  </h3>
                  
                  <div className="p-4 border-2 border-black rounded-xl bg-slate-50">
                    <div className="flex items-center gap-2 mb-3">
                      <Search className="text-slate-500" size={18} />
                      <input
                        type="text"
                        placeholder="Rechercher des tags (ex: Vente, Transport)..."
                        value={tagSearchQuery}
                        onChange={(e) => setTagSearchQuery(e.target.value)}
                        className="w-full bg-transparent outline-none font-bold text-sm text-black"
                      />
                      {tagSearchQuery && (
                        <button type="button" onClick={() => setTagSearchQuery('')}>
                          <X size={16} />
                        </button>
                      )}
                    </div>

                    {selectedTags.size > 0 && (
                      <div className="flex flex-wrap gap-2 mb-3 border-b-2 border-slate-200 pb-3">
                        {Array.from(selectedTags).map((tag) => (
                          <span
                            key={tag}
                            className="inline-flex items-center gap-1 bg-[#10B981] text-white border border-black text-xs font-black px-3 py-1 rounded-full shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]"
                          >
                            {tag}
                            <button
                              type="button"
                              onClick={() => handleRemoveTag(tag)}
                              className="hover:text-red-200"
                            >
                              <X size={12} />
                            </button>
                          </span>
                        ))}
                      </div>
                    )}

                    {isLoadingTags ? (
                      <div className="flex items-center gap-2 text-xs font-bold text-slate-500">
                        <RefreshCw className="animate-spin" size={14} /> Chargement des tags...
                      </div>
                    ) : filteredTags.length === 0 ? (
                      <div className="text-xs font-bold text-slate-400">Aucun tag correspondant.</div>
                    ) : (
                      <div className="max-h-36 overflow-y-auto flex flex-wrap gap-2 pt-1">
                        {filteredTags.map((tag) => {
                          const isSelected = selectedTags.has(tag);
                          return (
                            <button
                              type="button"
                              key={tag}
                              onClick={() => handleTagToggle(tag)}
                              className={`text-xs font-bold px-3 py-1.5 rounded-full border-2 transition-all active:scale-95 ${
                                isSelected
                                  ? 'bg-[#FEF08A] border-black text-black shadow-[2px_2px_0px_0px_rgba(0,0,0,1)]'
                                  : 'bg-white border-slate-200 text-slate-600 hover:border-black'
                              }`}
                            >
                              {tag}
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </div>
                </div>

                {/* Section : Moyens de contact */}
                <div className="space-y-4">
                  <h3 className="text-xs font-black uppercase tracking-wider text-primary border-l-4 border-primary pl-2">
                    Moyens de contact
                  </h3>
                  <p className="text-xs text-slate-500 font-bold">
                    Veuillez renseigner au moins un e-mail de réception de CV ou un numéro de téléphone WhatsApp pour les échanges de Matchs.
                  </p>

                  <div className="grid md:grid-cols-2 gap-5">
                    <div>
                      <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                        Adresse e-mail
                      </label>
                      <div className="relative">
                        <Mail className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                          type="email"
                          name="email"
                          value={formData.email}
                          onChange={handleInputChange}
                          placeholder="Ex: recrutement@entreprise.com"
                          className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-xs font-black uppercase tracking-wider text-black mb-1.5">
                        Numéro WhatsApp *
                      </label>
                      <div className="relative">
                        <Phone className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                        <input
                          type="tel"
                          name="phone"
                          value={formData.phone}
                          onChange={handleInputChange}
                          placeholder="Ex: 07070707"
                          className="w-full pl-10 pr-4 py-3 bg-slate-50 border-2 border-black rounded-xl focus:translate-x-[2px] focus:translate-y-[2px] focus:shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] outline-none transition-all font-bold placeholder:text-slate-400 text-black"
                        />
                      </div>
                    </div>
                  </div>
                </div>

                {/* Letter requirement Switch */}
                <div className="flex items-center justify-between p-4 border-2 border-black rounded-xl bg-slate-50">
                  <div className="space-y-0.5">
                    <p className="text-sm font-black text-black uppercase tracking-wide">Lettre de motivation</p>
                    <p className="text-xs font-bold text-slate-500">Exiger une lettre de motivation écrite au moment du match.</p>
                  </div>
                  <button
                    type="button"
                    onClick={() => setRequiresCoverLetter(!requiresCoverLetter)}
                    className="focus:outline-none transition-transform active:scale-95"
                  >
                    <div
                      className={`w-12 h-6 border-2 border-black rounded-full relative transition-all ${
                        requiresCoverLetter ? 'bg-[#10B981]' : 'bg-slate-200'
                      }`}
                    >
                      <div
                        className={`w-4 h-4 bg-white border-2 border-black rounded-full absolute top-0.5 transition-all ${
                          requiresCoverLetter ? 'left-6.5' : 'left-0.5'
                        }`}
                      ></div>
                    </div>
                  </button>
                </div>

                {/* Legal warning */}
                <div className="bg-red-100 border-4 border-black p-5 rounded-2xl flex gap-4 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]">
                  <Gavel className="text-red-600 shrink-0 mt-0.5" size={24} />
                  <div className="space-y-1">
                    <p className="font-black text-red-950 uppercase text-sm tracking-wide">Avertissement légal</p>
                    <p className="text-xs font-bold text-red-700 leading-relaxed">
                      Toute publication d'offre frauduleuse, mensongère ou d'arnaques est punie par la loi ivoirienne de répression de la cybercriminalité. Votre adresse IP et vos informations d'identité sont consignées à des fins de vérification légale en cas d'infraction.
                    </p>
                  </div>
                </div>

                {/* Submit button */}
                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-full bg-[#10B981] hover:bg-[#059669] text-white border-4 border-black font-black py-4 rounded-xl shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[4px] active:translate-y-[4px] transition-all flex items-center justify-center gap-2 uppercase tracking-widest disabled:opacity-50"
                >
                  {isLoading ? (
                    <>
                      <RefreshCw className="animate-spin" size={20} />
                      Soumission...
                    </>
                  ) : (
                    <>
                      <Briefcase size={20} />
                      Soumettre l'offre d'emploi
                    </>
                  )}
                </button>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default RecruiterPage;
