import React, { useEffect, useState } from 'react';
import {
  FileText,
  ToggleLeft,
  ToggleRight,
  AlertCircle,
  CheckCircle2,
  RefreshCw,
  CalendarDays,
  Info,
  Users,
  TrendingUp,
  Award,
  Search,
  ChevronDown,
  ChevronUp,
  Eye,
  FileSpreadsheet
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface CvTrialConfig {
  cv_trial_active: boolean;
  cv_trial_end_date: string; // ISO string or ''
}

interface CvItem {
  id: string;
  title: string;
  templateId: string;
  primaryColor: string;
  secondaryColor: string;
  createdAt: string;
}

interface CvUser {
  id: string;
  name: string;
  phone: string;
  isPremium: boolean;
  skills: string[];
  cvs: CvItem[];
  lastCvDate: string;
}

const templateLabels: Record<string, string> = {
  classic: 'Classique',
  modern: 'Moderne',
  creative: 'Créatif',
  professional: 'Professionnel',
  minimalist: 'Minimaliste',
};

const CvTrialTab: React.FC = () => {
  // Configuration State
  const [config, setConfig] = useState<CvTrialConfig>({
    cv_trial_active: false,
    cv_trial_end_date: '',
  });
  const [pricingConfig, setPricingConfig] = useState({
    premium_price_cfa: 2000,
    extra_cv_price_cfa: 500,
  });
  const [isFetching, setIsFetching] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [isSavingPricing, setIsSavingPricing] = useState(false);
  const [pricingError, setPricingError] = useState('');
  const [pricingSuccess, setPricingSuccess] = useState('');

  // CV Usage Metrics & Users State
  const [cvUsers, setCvUsers] = useState<CvUser[]>([]);
  const [metrics, setMetrics] = useState({
    totalCvs: 0,
    totalCreators: 0,
    avgCvsPerCreator: 0,
  });
  const [templateCounts, setTemplateCounts] = useState<Record<string, number>>({});
  const [cvSearchTerm, setCvSearchTerm] = useState('');
  const [expandedUserId, setExpandedUserId] = useState<string | null>(null);
  const [isLoadingCvData, setIsLoadingCvData] = useState(true);
  const [cvFetchError, setCvFetchError] = useState('');

  useEffect(() => {
    fetchConfig();
    fetchCvData();
  }, []);

  const fetchConfig = async () => {
    setIsFetching(true);
    try {
      const { data, error: fetchError } = await supabase
        .from('app_config')
        .select('cv_trial_active, cv_trial_end_date, premium_price_cfa, extra_cv_price_cfa')
        .eq('id', 1)
        .maybeSingle();

      if (fetchError) throw fetchError;

      if (data) {
        setConfig({
          cv_trial_active: data.cv_trial_active ?? false,
          cv_trial_end_date: data.cv_trial_end_date
            ? new Date(data.cv_trial_end_date).toISOString().slice(0, 16) // datetime-local format
            : '',
        });
        setPricingConfig({
          premium_price_cfa: data.premium_price_cfa ?? 2000,
          extra_cv_price_cfa: data.extra_cv_price_cfa ?? 500,
        });
      }
    } catch (e: any) {
      setError(e.message || 'Impossible de charger la configuration.');
    } finally {
      setIsFetching(false);
    }
  };

  const fetchCvData = async () => {
    setIsLoadingCvData(true);
    setCvFetchError('');
    try {
      // Fetch all CVs
      const { data: cvs, error: cvsErr } = await supabase
        .from('user_cvs')
        .select('id, user_id, title, template_id, primary_color, secondary_color, created_at')
        .order('created_at', { ascending: false });

      if (cvsErr) throw cvsErr;

      if (!cvs || cvs.length === 0) {
        setCvUsers([]);
        setTemplateCounts({});
        setMetrics({
          totalCvs: 0,
          totalCreators: 0,
          avgCvsPerCreator: 0,
        });
        return;
      }

      // Fetch unique user profiles
      const userIds = Array.from(new Set(cvs.map((c: any) => c.user_id)));
      const { data: profiles, error: profilesErr } = await supabase
        .from('profiles')
        .select('id, full_name, phone_number, is_premium, skills')
        .in('id', userIds);

      if (profilesErr) throw profilesErr;

      const profilesMap = (profiles || []).reduce((acc: any, p: any) => {
        acc[p.id] = p;
        return acc;
      }, {});

      // Build CV User list
      const cvUsersList: CvUser[] = [];
      const userCvGroups: Record<string, any[]> = {};

      cvs.forEach((cv: any) => {
        if (!userCvGroups[cv.user_id]) {
          userCvGroups[cv.user_id] = [];
        }
        userCvGroups[cv.user_id].push(cv);
      });

      Object.entries(userCvGroups).forEach(([userId, userCvs]) => {
        const profile = profilesMap[userId];
        cvUsersList.push({
          id: userId,
          name: profile?.full_name || 'Utilisateur Anonyme',
          phone: profile?.phone_number || '-',
          isPremium: profile?.is_premium || false,
          skills: Array.isArray(profile?.skills) ? profile.skills : [],
          cvs: userCvs.map((c: any) => ({
            id: c.id,
            title: c.title || 'Mon CV',
            templateId: c.template_id || 'classic',
            primaryColor: c.primary_color || '#1E3A8A',
            secondaryColor: c.secondary_color || '#4B5563',
            createdAt: c.created_at
          })),
          lastCvDate: userCvs[0]?.created_at || '' // cvs are sorted desc
        });
      });

      // Sort users by last CV date desc
      cvUsersList.sort((a, b) => new Date(b.lastCvDate).getTime() - new Date(a.lastCvDate).getTime());

      setCvUsers(cvUsersList);

      // Compute metrics
      const totalCvs = cvs.length;
      const totalCreators = cvUsersList.length;
      const avgCvsPerCreator = totalCreators > 0 ? Number((totalCvs / totalCreators).toFixed(1)) : 0;

      // Compute template counts
      const counts: Record<string, number> = {};
      cvs.forEach((c: any) => {
        const tId = c.template_id || 'classic';
        counts[tId] = (counts[tId] || 0) + 1;
      });

      setTemplateCounts(counts);
      setMetrics({
        totalCvs,
        totalCreators,
        avgCvsPerCreator,
      });
    } catch (e: any) {
      console.error('Error fetching CV metrics:', e);
      setCvFetchError(e.message || 'Erreur lors du chargement des métriques CV.');
    } finally {
      setIsLoadingCvData(false);
    }
  };

  const handleSave = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    setIsSaving(true);
    try {
      const endDate = config.cv_trial_end_date
        ? new Date(config.cv_trial_end_date).toISOString()
        : null;

      const { error: saveError } = await supabase
        .from('app_config')
        .update({
          cv_trial_active: config.cv_trial_active,
          cv_trial_end_date: endDate,
        })
        .eq('id', 1);

      if (saveError) throw saveError;

      setSuccess(
        config.cv_trial_active
          ? 'Période d\'essai activée. Le paywall CV est bypassé sur l\'app en temps réel.'
          : 'Période d\'essai désactivée. Le tarif normal (500 F CFA) est rétabli.'
      );
    } catch (e: any) {
      setError(e.message || "Erreur lors de l'enregistrement.");
    } finally {
      setIsSaving(false);
    }
  };

  const handleSavePricing = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setPricingError('');
    setPricingSuccess('');

    const premiumPrice = Number(pricingConfig.premium_price_cfa);
    const extraCvPrice = Number(pricingConfig.extra_cv_price_cfa);

    if (isNaN(premiumPrice) || premiumPrice < 0) {
      setPricingError('Le prix premium doit être un nombre positif ou nul.');
      return;
    }
    if (isNaN(extraCvPrice) || extraCvPrice < 0) {
      setPricingError('Le prix du CV supplémentaire doit être un nombre positif ou nul.');
      return;
    }

    setIsSavingPricing(true);
    try {
      const { error: saveError } = await supabase
        .from('app_config')
        .update({
          premium_price_cfa: premiumPrice,
          extra_cv_price_cfa: extraCvPrice,
        })
        .eq('id', 1);

      if (saveError) throw saveError;

      setPricingSuccess('Tarification enregistrée avec succès. Les modifications sont appliquées sur l\'application en temps réel.');
    } catch (e: any) {
      setPricingError(e.message || "Erreur lors de l'enregistrement de la tarification.");
    } finally {
      setIsSavingPricing(false);
    }
  };


  const toggleExpandUser = (userId: string) => {
    if (expandedUserId === userId) {
      setExpandedUserId(null);
    } else {
      setExpandedUserId(userId);
    }
  };

  /** Calcule les jours restants si une date de fin est définie */
  const daysRemaining = (): number | null => {
    if (!config.cv_trial_end_date) return null;
    const end = new Date(config.cv_trial_end_date);
    const now = new Date();
    const diff = Math.ceil((end.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    return diff;
  };

  const days = daysRemaining();
  const isExpired = days !== null && days <= 0;

  // Filter CV users list based on search term
  const filteredCvUsers = cvUsers.filter((u) => {
    const term = cvSearchTerm.toLowerCase();
    return (
      u.name.toLowerCase().includes(term) ||
      u.phone.includes(term) ||
      u.cvs.some((c) => c.title.toLowerCase().includes(term))
    );
  });

  if (isFetching) {
    return (
      <div className="max-w-2xl mx-auto flex items-center justify-center py-20 text-slate-400 gap-3">
        <RefreshCw className="animate-spin" size={20} />
        Chargement de la configuration...
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-12">
      
      {/* Upper Grid: Configurations & General Stats */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        
        {/* Left Column: Form Settings (5/12 width on lg) */}
        <div className="lg:col-span-5 space-y-6">
          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between">
            <div>
              <h2 className="text-lg font-heading mb-1 flex items-center gap-2 text-slate-900">
                <FileText className="text-primary" size={22} /> Période d'essai — CV
              </h2>
              <p className="text-xs text-slate-500 mb-5">
                Bypassez le paywall du générateur de CV (500 F CFA) en temps réel pour tous les utilisateurs.
              </p>

              <form onSubmit={handleSave} className="space-y-5">
                {/* Toggle */}
                <div className="flex items-center justify-between p-3.5 bg-slate-50 rounded-xl border border-slate-200">
                  <div>
                    <p className="text-sm font-semibold text-slate-800">Période d'essai gratuite</p>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      {config.cv_trial_active
                        ? 'Active — paywall bypassé sur l\'app'
                        : 'Inactive — tarif normal en vigueur'}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      setConfig((c) => ({ ...c, cv_trial_active: !c.cv_trial_active }))
                    }
                    className="focus:outline-none transition-transform active:scale-95"
                    aria-label="Activer/désactiver la période d'essai"
                  >
                    {config.cv_trial_active ? (
                      <ToggleRight size={44} className="text-primary" />
                    ) : (
                      <ToggleLeft size={44} className="text-slate-300" />
                    )}
                  </button>
                </div>

                {/* Date de fin */}
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-slate-700 flex items-center gap-1.5">
                    <CalendarDays size={14} />
                    Date et heure de fin (optionnel)
                  </label>
                  <input
                    type="datetime-local"
                    value={config.cv_trial_end_date}
                    onChange={(e) =>
                      setConfig((c) => ({ ...c, cv_trial_end_date: e.target.value }))
                    }
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>

                {/* Status indicator */}
                {config.cv_trial_end_date && (
                  <div
                    className={`flex items-start gap-2.5 px-3.5 py-2.5 rounded-xl text-xs ${
                      isExpired
                        ? 'bg-red-50 text-red-600 border border-red-100'
                        : 'bg-blue-50 text-blue-600 border border-blue-100'
                    }`}
                  >
                    <Info size={14} className="mt-0.5 shrink-0" />
                    {isExpired ? (
                      <span>
                        Le trial est <strong>dépassé</strong> — paywall actif côté app.
                      </span>
                    ) : (
                      <span>
                        Il reste <strong>{days} jour{(days ?? 0) > 1 ? 's' : ''}</strong> avant la fin automatique.
                      </span>
                    )}
                  </div>
                )}

                {error && (
                  <div className="bg-red-50 text-red-600 px-3 py-2.5 rounded-xl flex items-center gap-2 text-xs">
                    <AlertCircle size={14} /> {error}
                  </div>
                )}
                {success && (
                  <div className="bg-green-50 text-green-600 px-3 py-2.5 rounded-xl flex items-center gap-2 text-xs animate-in zoom-in duration-300">
                    <CheckCircle2 size={14} /> {success}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isSaving}
                  className="w-full bg-primary text-white py-2.5 rounded-xl font-bold text-sm hover:shadow-lg hover:shadow-primary/20 active:scale-95 transition-all disabled:opacity-50 disabled:active:scale-100 flex items-center justify-center gap-2"
                >
                  {isSaving ? (
                    <>
                      <RefreshCw className="animate-spin" size={16} />
                      Enregistrement...
                    </>
                  ) : (
                    'Enregistrer'
                  )}
                </button>
              </form>
            </div>

            <div className="bg-amber-50 border border-amber-100 rounded-xl p-3.5 mt-5 text-[11px] text-amber-700 flex gap-2.5">
              <Info size={16} className="shrink-0 mt-0.5 text-amber-500" />
              <div>
                <p className="font-semibold">Bypass en temps réel</p>
                <p className="text-amber-600 mt-0.5 leading-relaxed">
                  L'activation du toggle met à jour Supabase instantanément. L'application Flutter s'adapte sans redémarrage via Supabase Realtime.
                </p>
              </div>
            </div>
          </div>

          {/* Card 2: Tarification Premium & CV */}
          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between">
            <div>
              <h2 className="text-lg font-heading mb-1 flex items-center gap-2 text-slate-900">
                <TrendingUp className="text-cta" size={22} /> Tarification Premium & CV
              </h2>
              <p className="text-xs text-slate-500 mb-5">
                Ajustez le prix de l'abonnement Premium et des CV supplémentaires de l'application en Francs CFA.
              </p>

              <form onSubmit={handleSavePricing} className="space-y-5">
                {/* Abonnement Premium */}
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-slate-700">
                    Forfait Illimité (Premium) / mois (F CFA)
                  </label>
                  <input
                    type="number"
                    min={0}
                    value={pricingConfig.premium_price_cfa}
                    onChange={(e) =>
                      setPricingConfig((c) => ({
                        ...c,
                        premium_price_cfa: parseInt(e.target.value, 10) || 0,
                      }))
                    }
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>

                {/* CV Supplémentaire */}
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-slate-700">
                    Tarif du CV supplémentaire (F CFA)
                  </label>
                  <input
                    type="number"
                    min={0}
                    value={pricingConfig.extra_cv_price_cfa}
                    onChange={(e) =>
                      setPricingConfig((c) => ({
                        ...c,
                        extra_cv_price_cfa: parseInt(e.target.value, 10) || 0,
                      }))
                    }
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>

                {pricingError && (
                  <div className="bg-red-50 text-red-600 px-3 py-2.5 rounded-xl flex items-center gap-2 text-xs">
                    <AlertCircle size={14} /> {pricingError}
                  </div>
                )}
                {pricingSuccess && (
                  <div className="bg-green-50 text-green-600 px-3 py-2.5 rounded-xl flex items-center gap-2 text-xs animate-in zoom-in duration-300">
                    <CheckCircle2 size={14} /> {pricingSuccess}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isSavingPricing}
                  className="w-full bg-primary text-white py-2.5 rounded-xl font-bold text-sm hover:shadow-lg hover:shadow-primary/20 active:scale-95 transition-all disabled:opacity-50 disabled:active:scale-100 flex items-center justify-center gap-2"
                >
                  {isSavingPricing ? (
                    <>
                      <RefreshCw className="animate-spin" size={16} />
                      Enregistrement...
                    </>
                  ) : (
                    'Enregistrer la tarification'
                  )}
                </button>
              </form>
            </div>
          </div>
        </div>

        {/* Right Column: CV Generation Metrics (7/12 width on lg) */}
        <div className="lg:col-span-7 flex flex-col justify-between bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <div>
            <div className="flex justify-between items-center mb-6">
              <div>
                <h2 className="text-lg font-heading text-slate-900 flex items-center gap-2">
                  <TrendingUp className="text-cta" size={22} /> Métriques d'Utilisation
                </h2>
                <p className="text-xs text-slate-500">Statistiques globales sur la création de CV.</p>
              </div>
              <button
                onClick={fetchCvData}
                disabled={isLoadingCvData}
                className="p-1.5 text-slate-400 hover:text-slate-600 bg-slate-50 border border-slate-200 rounded-lg transition-all active:scale-95 disabled:opacity-50"
                title="Rafraîchir les métriques"
              >
                <RefreshCw size={16} className={isLoadingCvData ? 'animate-spin' : ''} />
              </button>
            </div>

            {cvFetchError ? (
              <div className="bg-red-50 text-red-600 p-4 rounded-xl flex items-center gap-2 text-sm">
                <AlertCircle size={16} /> {cvFetchError}
              </div>
            ) : isLoadingCvData ? (
              <div className="flex flex-col items-center justify-center py-16 text-slate-400 gap-2">
                <RefreshCw className="animate-spin" size={24} />
                <p className="text-xs">Chargement des statistiques...</p>
              </div>
            ) : (
              <div className="space-y-6">
                {/* Metrics Cards Grid */}
                <div className="grid grid-cols-3 gap-4">
                  <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                    <div className="flex items-center justify-between text-slate-400 mb-1">
                      <span className="text-[10px] font-bold uppercase tracking-wider">CV Générés</span>
                      <FileText size={16} className="text-primary" />
                    </div>
                    <p className="text-2xl font-black text-slate-950">{metrics.totalCvs}</p>
                    <p className="text-[10px] text-slate-400 mt-1">Total de CVs créés</p>
                  </div>

                  <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                    <div className="flex items-center justify-between text-slate-400 mb-1">
                      <span className="text-[10px] font-bold uppercase tracking-wider">Créateurs</span>
                      <Users size={16} className="text-cta" />
                    </div>
                    <p className="text-2xl font-black text-slate-950">{metrics.totalCreators}</p>
                    <p className="text-[10px] text-slate-400 mt-1">Utilisateurs uniques</p>
                  </div>

                  <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                    <div className="flex items-center justify-between text-slate-400 mb-1">
                      <span className="text-[10px] font-bold uppercase tracking-wider">Moyenne</span>
                      <Award size={16} className="text-purple-600" />
                    </div>
                    <p className="text-2xl font-black text-slate-950">{metrics.avgCvsPerCreator}</p>
                    <p className="text-[10px] text-slate-400 mt-1">CVs par utilisateur</p>
                  </div>
                </div>

                {/* Popular Templates */}
                <div className="space-y-3">
                  <h3 className="text-xs font-bold text-slate-400 uppercase tracking-widest flex items-center gap-1.5">
                    <FileSpreadsheet size={14} /> Répartition des modèles de CV
                  </h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-3 bg-slate-50 border border-slate-200 rounded-xl p-4">
                    {Object.keys(templateLabels).map((templateId) => {
                      const count = templateCounts[templateId] || 0;
                      const percentage = metrics.totalCvs > 0 ? Math.round((count / metrics.totalCvs) * 100) : 0;
                      return (
                        <div key={templateId} className="space-y-1">
                          <div className="flex justify-between text-[11px] font-bold text-slate-600">
                            <span>{templateLabels[templateId]}</span>
                            <span>{count} ({percentage}%)</span>
                          </div>
                          <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
                            <div
                              className="bg-primary h-full rounded-full transition-all duration-500"
                              style={{ width: `${percentage}%` }}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Lower Section: Searchable Users & CVs list */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="p-6 border-b border-slate-200 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h3 className="text-lg font-heading text-slate-900">Utilisateurs du Générateur de CV</h3>
            <p className="text-xs text-slate-500">Consultez qui utilise le service CV de l'application.</p>
          </div>

          <div className="relative w-full md:w-80">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
            <input
              type="text"
              value={cvSearchTerm}
              onChange={(e) => setCvSearchTerm(e.target.value)}
              placeholder="Rechercher (Nom, Mobile, Titre CV...)"
              className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all"
            />
          </div>
        </div>

        {cvFetchError ? null : isLoadingCvData ? (
          <div className="flex flex-col items-center justify-center py-24 text-slate-400 gap-2">
            <RefreshCw className="animate-spin" size={32} />
            <p className="text-sm">Chargement des utilisateurs de CV...</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead className="bg-slate-50 text-slate-500 text-[10px] font-black uppercase tracking-widest border-b border-slate-100">
                <tr>
                  <th className="px-6 py-4">Participant</th>
                  <th className="px-6 py-4">Contact</th>
                  <th className="px-6 py-4">Statut</th>
                  <th className="px-6 py-4 text-center">Nombre de CV</th>
                  <th className="px-6 py-4">Dernière activité</th>
                  <th className="px-6 py-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredCvUsers.map((user) => {
                  const isExpanded = expandedUserId === user.id;
                  return (
                    <React.Fragment key={user.id}>
                      <tr className="hover:bg-slate-50/50 transition-colors group">
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <div
                              className={`w-9 h-9 rounded-xl flex items-center justify-center font-bold text-xs ${
                                user.isPremium ? 'bg-cta text-white shadow-sm' : 'bg-slate-100 text-slate-500'
                              }`}
                            >
                              {user.name.charAt(0)}
                            </div>
                            <div>
                              <p className="font-bold text-slate-900 leading-none text-sm">{user.name}</p>
                              <p className="text-[10px] text-slate-400 mt-1 font-mono uppercase">
                                #{user.id.substring(0, 8)}
                              </p>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <p className="text-xs font-semibold text-slate-700">{user.phone}</p>
                        </td>
                        <td className="px-6 py-4">
                          <span
                            className={`px-2.5 py-0.5 rounded-lg text-[9px] font-black uppercase tracking-tight ${
                              user.isPremium
                                ? 'bg-cta text-white shadow-sm shadow-cta/20'
                                : 'bg-slate-100 text-slate-500'
                            }`}
                          >
                            {user.isPremium ? 'Premium' : 'Standard'}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-center">
                          <span className="px-2 py-0.5 bg-primary/10 text-primary border border-primary/20 rounded-md text-xs font-bold">
                            {user.cvs.length}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          <p className="text-xs text-slate-500 font-medium">
                            {new Date(user.lastCvDate).toLocaleDateString('fr-FR', {
                              day: 'numeric',
                              month: 'short',
                              year: 'numeric',
                            })}
                          </p>
                        </td>
                        <td className="px-6 py-4 text-right">
                          <button
                            onClick={() => toggleExpandUser(user.id)}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 rounded-lg text-xs font-bold text-slate-600 bg-white hover:bg-slate-50 transition-colors"
                          >
                            <Eye size={12} />
                            {isExpanded ? 'Masquer' : 'Voir CVs'}
                            {isExpanded ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
                          </button>
                        </td>
                      </tr>

                      {/* Expanded Section showing individual CV details */}
                      {isExpanded && (
                        <tr className="bg-slate-50/30">
                          <td colSpan={6} className="px-8 py-5 border-t border-b border-slate-200/50">
                            <div className="space-y-4">
                              <div className="flex justify-between items-center">
                                <p className="text-xs font-black text-slate-400 uppercase tracking-widest">
                                  Détails des CV créés par l'utilisateur ({user.cvs.length})
                                </p>
                              </div>
                              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {user.cvs.map((cv) => (
                                  <div
                                    key={cv.id}
                                    className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex items-start gap-4 hover:border-slate-350 transition-all hover:shadow"
                                  >
                                    {/* CV Thumbnail mockup */}
                                    <div className="w-10 h-12 rounded-lg border border-slate-200 flex flex-col overflow-hidden shrink-0 shadow-inner">
                                      <div className="h-3 w-full" style={{ backgroundColor: cv.primaryColor }} />
                                      <div className="h-2.5 w-full" style={{ backgroundColor: cv.secondaryColor }} />
                                      <div className="flex-1 bg-slate-50 flex items-center justify-center">
                                        <FileText size={16} className="text-slate-400" />
                                      </div>
                                    </div>
                                    <div className="space-y-1.5 flex-1 min-w-0">
                                      <p className="font-bold text-slate-800 text-sm truncate">{cv.title}</p>
                                      <div className="flex flex-wrap gap-2 items-center">
                                        <span className="px-2 py-0.5 bg-slate-100 text-[10px] font-bold rounded text-slate-600">
                                          Modèle : {templateLabels[cv.templateId] || cv.templateId}
                                        </span>
                                        <span className="text-[10px] text-slate-400">
                                          Créé le{' '}
                                          {new Date(cv.createdAt).toLocaleDateString('fr-FR', {
                                            day: 'numeric',
                                            month: 'short',
                                            year: 'numeric',
                                            hour: '2-digit',
                                            minute: '2-digit',
                                          })}
                                        </span>
                                      </div>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })}

                {filteredCvUsers.length === 0 && (
                  <tr>
                    <td colSpan={6} className="px-6 py-20 text-center">
                      <FileText size={40} className="mx-auto text-slate-200 mb-2" />
                      <p className="text-slate-400 italic">Aucun créateur de CV trouvé.</p>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

export default CvTrialTab;
