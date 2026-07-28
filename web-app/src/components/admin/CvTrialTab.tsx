import React, { useEffect, useMemo, useRef, useState } from "react";
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
  Briefcase,
  Search,
  ChevronDown,
  ChevronUp,
  Eye,
  FileSpreadsheet,
  Coins,
  Sparkles,
  Crown,
  Plus,
  Trash2,
  Edit3,
  Check,
  X,
} from "lucide-react";
import { supabase, fetchProfilesInBatches } from "../../lib/supabase";

interface CreditPack {
  id: string;
  name: string;
  credits: number;
  price_cfa: number;
  badge: string;
  is_recommended: boolean;
  is_active: boolean;
  display_order: number;
}

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
  classic: "Classique",
  modern: "Moderne",
  creative: "Créatif",
  professional: "Professionnel",
  minimalist: "Minimaliste",
};

interface CvTrialTabProps {
  focusSection?: "ai-adapt-stats" | null;
  onFocusHandled?: () => void;
}

const extractAdaptedJobTitle = (title?: string): string | null => {
  if (!title) return null;

  const match = title.match(/adapt[ée]\s+pour\s+(.+)$/i);
  if (!match?.[1]) return null;

  const jobTitle = match[1].trim();
  return jobTitle.length > 0 ? jobTitle : null;
};

const CvTrialTab: React.FC<CvTrialTabProps> = ({
  focusSection = null,
  onFocusHandled,
}) => {
  // Configuration State
  const [config, setConfig] = useState<CvTrialConfig>({
    cv_trial_active: false,
    cv_trial_end_date: "",
  });
  const [pricingConfig, setPricingConfig] = useState({
    premium_price_cfa: 2000,
    extra_cv_price_cfa: 500,
  });
  const [isFetching, setIsFetching] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const [isSavingPricing, setIsSavingPricing] = useState(false);
  const [pricingError, setPricingError] = useState("");
  const [pricingSuccess, setPricingSuccess] = useState("");

  // AI CV Adaptation State
  const [aiConfig, setAiConfig] = useState({
    ai_adapt_enabled: true,
    ai_adapt_trial_active: true,
    ai_adapt_trial_end_date: "",
    ai_adapt_free_limit: 10,
    ai_adapt_price: 500,
    ai_adapt_premium_limit: 5,
  });
  const [isSavingAi, setIsSavingAi] = useState(false);
  const [aiError, setAiError] = useState("");
  const [aiSuccess, setAiSuccess] = useState("");

  // Premium Features Toggles State
  const [premiumFeatures, setPremiumFeatures] = useState({
    feat_unlimited_swipes: true,
    feat_unlocked_history: true,
    feat_certified_badge: true,
    feat_rewind: true,
    feat_email_alerts: true,
    feat_extra_cvs: true,
    feat_ai_adaptation: true,
  });

  // Credit Packs State
  const [creditPacks, setCreditPacks] = useState<CreditPack[]>([]);
  const [isLoadingPacks, setIsLoadingPacks] = useState(false);
  const [packError, setPackError] = useState("");
  const [packSuccess, setPackSuccess] = useState("");
  const [editingPackId, setEditingPackId] = useState<string | null>(null);
  const [editingPack, setEditingPack] = useState<Partial<CreditPack>>({});
  const [isAddingPack, setIsAddingPack] = useState(false);
  const [newPack, setNewPack] = useState<Partial<CreditPack>>({
    id: "",
    name: "",
    credits: 5,
    price_cfa: 1000,
    badge: "",
    is_recommended: false,
    is_active: true,
    display_order: 4,
  });

  // CV Usage Metrics & Users State
  const [cvUsers, setCvUsers] = useState<CvUser[]>([]);
  const [metrics, setMetrics] = useState({
    totalCvs: 0,
    totalCreators: 0,
    avgCvsPerCreator: 0,
  });
  const [templateCounts, setTemplateCounts] = useState<Record<string, number>>(
    {},
  );
  const [cvSearchTerm, setCvSearchTerm] = useState("");
  const [expandedUserId, setExpandedUserId] = useState<string | null>(null);
  const [isLoadingCvData, setIsLoadingCvData] = useState(true);
  const [cvFetchError, setCvFetchError] = useState("");
  const aiAdaptStatsRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    fetchConfig();
    fetchCvData();
    fetchCreditPacks();
  }, []);

  const fetchCreditPacks = async () => {
    setIsLoadingPacks(true);
    setPackError("");
    try {
      const { data, error } = await supabase
        .from("credit_packs")
        .select("*")
        .order("display_order", { ascending: true });

      if (error) throw error;
      setCreditPacks(data || []);
    } catch (e: any) {
      console.error("Error fetching credit packs:", e);
      setPackError(
        `Impossible de charger les packs de crédits (${e?.message || "Erreur inconnue"}).`,
      );
    } finally {
      setIsLoadingPacks(false);
    }
  };

  const togglePackActive = async (pack: CreditPack) => {
    setPackError("");
    setPackSuccess("");
    try {
      const updatedActive = !pack.is_active;
      const { error } = await supabase
        .from("credit_packs")
        .update({
          is_active: updatedActive,
          updated_at: new Date().toISOString(),
        })
        .eq("id", pack.id);

      if (error) throw error;

      setCreditPacks((prev) =>
        prev.map((p) =>
          p.id === pack.id ? { ...p, is_active: updatedActive } : p,
        ),
      );
      setPackSuccess(
        `Le ${pack.name} est maintenant ${updatedActive ? "ACTIVÉ" : "DÉSACTIVÉ"}.`,
      );
    } catch (e: any) {
      setPackError(e.message || "Erreur lors du changement de statut du pack.");
    }
  };

  const startEditPack = (pack: CreditPack) => {
    setEditingPackId(pack.id);
    setEditingPack({ ...pack });
  };

  const handleSaveEditPack = async (packId: string) => {
    if (!editingPack) return;
    setPackError("");
    setPackSuccess("");

    try {
      const { error } = await supabase
        .from("credit_packs")
        .update({
          name: editingPack.name,
          credits: Number(editingPack.credits),
          price_cfa: Number(editingPack.price_cfa),
          badge: editingPack.badge || "",
          is_recommended: !!editingPack.is_recommended,
          is_active: editingPack.is_active ?? true,
          display_order: Number(editingPack.display_order) || 1,
          updated_at: new Date().toISOString(),
        })
        .eq("id", packId);

      if (error) throw error;

      setCreditPacks((prev) =>
        prev.map((p) =>
          p.id === packId ? ({ ...p, ...editingPack } as CreditPack) : p,
        ),
      );
      setEditingPackId(null);
      setEditingPack({});
      setPackSuccess("Pack de crédits mis à jour avec succès !");
    } catch (e: any) {
      setPackError(e.message || "Erreur lors de la mise à jour du pack.");
    }
  };

  const handleCreatePack = async (e: React.FormEvent) => {
    e.preventDefault();
    setPackError("");
    setPackSuccess("");

    if (!newPack.name || !newPack.credits || !newPack.price_cfa) {
      setPackError(
        "Veuillez renseigner au moins le nom, les crédits et le prix.",
      );
      return;
    }

    const packId = newPack.id ? newPack.id.trim() : `pack_${Date.now()}`;
    const payload: CreditPack = {
      id: packId,
      name: newPack.name,
      credits: Number(newPack.credits),
      price_cfa: Number(newPack.price_cfa),
      badge: newPack.badge || "",
      is_recommended: !!newPack.is_recommended,
      is_active: newPack.is_active ?? true,
      display_order: Number(newPack.display_order) || creditPacks.length + 1,
    };

    try {
      const { error } = await supabase.from("credit_packs").insert(payload);
      if (error) throw error;

      setCreditPacks((prev) => [...prev, payload]);
      setIsAddingPack(false);
      setNewPack({
        id: "",
        name: "",
        credits: 5,
        price_cfa: 1000,
        badge: "",
        is_recommended: false,
        is_active: true,
        display_order: creditPacks.length + 2,
      });
      setPackSuccess("Nouveau pack de crédits ajouté avec succès !");
    } catch (e: any) {
      setPackError(e.message || "Erreur lors de la création du pack.");
    }
  };

  const handleDeletePack = async (packId: string) => {
    if (!window.confirm("Voulez-vous vraiment supprimer ce pack de crédits ?"))
      return;
    setPackError("");
    setPackSuccess("");
    try {
      const { error } = await supabase
        .from("credit_packs")
        .delete()
        .eq("id", packId);
      if (error) throw error;
      setCreditPacks((prev) => prev.filter((p) => p.id !== packId));
      setPackSuccess("Pack de crédits supprimé avec succès.");
    } catch (e: any) {
      setPackError(e.message || "Erreur lors de la suppression du pack.");
    }
  };

  const fetchConfig = async () => {
    setIsFetching(true);
    try {
      const { data, error: fetchError } = await supabase
        .from("app_config")
        .select("*")
        .eq("id", 1)
        .maybeSingle();

      if (fetchError) throw fetchError;

      if (data) {
        setConfig({
          cv_trial_active: data.cv_trial_active ?? false,
          cv_trial_end_date: data.cv_trial_end_date
            ? new Date(data.cv_trial_end_date).toISOString().slice(0, 16) // datetime-local format
            : "",
        });
        setPricingConfig({
          premium_price_cfa: data.premium_price_cfa ?? 2000,
          extra_cv_price_cfa: data.extra_cv_price_cfa ?? 500,
        });
        setAiConfig({
          ai_adapt_enabled: data.ai_adapt_enabled ?? true,
          ai_adapt_trial_active: data.ai_adapt_trial_active ?? true,
          ai_adapt_trial_end_date: data.ai_adapt_trial_end_date
            ? new Date(data.ai_adapt_trial_end_date).toISOString().slice(0, 16)
            : "",
          ai_adapt_free_limit: data.ai_adapt_free_limit ?? 10,
          ai_adapt_price: data.ai_adapt_price ?? 500,
          ai_adapt_premium_limit: data.ai_adapt_premium_limit ?? 5,
        });
        setPremiumFeatures({
          feat_unlimited_swipes: data.feat_unlimited_swipes ?? true,
          feat_unlocked_history: data.feat_unlocked_history ?? true,
          feat_certified_badge: data.feat_certified_badge ?? true,
          feat_rewind: data.feat_rewind ?? true,
          feat_email_alerts: data.feat_email_alerts ?? true,
          feat_extra_cvs: data.feat_extra_cvs ?? true,
          feat_ai_adaptation: data.feat_ai_adaptation ?? true,
        });
      }
    } catch (e: any) {
      setError(e.message || "Impossible de charger la configuration.");
    } finally {
      setIsFetching(false);
    }
  };

  const fetchCvData = async () => {
    setIsLoadingCvData(true);
    setCvFetchError("");
    try {
      // Fetch ALL CVs using pagination (Supabase limits to 1000 per request)
      const PAGE_SIZE = 1000;
      let allCvs: any[] = [];
      let page = 0;
      let hasMore = true;

      while (hasMore) {
        const from = page * PAGE_SIZE;
        const to = from + PAGE_SIZE - 1;

        const { data: batch, error: batchErr } = await supabase
          .from("user_cvs")
          .select(
            "id, user_id, title, template_id, primary_color, secondary_color, created_at",
          )
          .order("created_at", { ascending: false })
          .range(from, to);

        if (batchErr) throw batchErr;

        if (batch && batch.length > 0) {
          allCvs = allCvs.concat(batch);
          hasMore = batch.length === PAGE_SIZE; // If we got a full page, there might be more
          page++;
        } else {
          hasMore = false;
        }
      }

      console.log(
        `[CV Metrics] Fetched ${allCvs.length} total CVs across ${page} page(s)`,
      );

      if (allCvs.length === 0) {
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
      const userIds = Array.from(
        new Set(allCvs.map((c: any) => c.user_id)),
      ) as string[];
      const { data: profiles, error: profilesErr } =
        await fetchProfilesInBatches(
          userIds,
          "id, full_name, phone_number, is_premium, skills",
        );

      if (profilesErr) throw profilesErr;

      const profilesMap = (profiles || []).reduce((acc: any, p: any) => {
        acc[p.id] = p;
        return acc;
      }, {});

      // Build CV User list
      const cvUsersList: CvUser[] = [];
      const userCvGroups: Record<string, any[]> = {};

      allCvs.forEach((cv: any) => {
        if (!userCvGroups[cv.user_id]) {
          userCvGroups[cv.user_id] = [];
        }
        userCvGroups[cv.user_id].push(cv);
      });

      Object.entries(userCvGroups).forEach(([userId, userCvs]) => {
        const profile = profilesMap[userId];
        cvUsersList.push({
          id: userId,
          name: profile?.full_name || "Utilisateur Anonyme",
          phone: profile?.phone_number || "-",
          isPremium: profile?.is_premium || false,
          skills: Array.isArray(profile?.skills) ? profile.skills : [],
          cvs: userCvs.map((c: any) => ({
            id: c.id,
            title: c.title || "Mon CV",
            templateId: c.template_id || "classic",
            primaryColor: c.primary_color || "#1E3A8A",
            secondaryColor: c.secondary_color || "#4B5563",
            createdAt: c.created_at,
          })),
          lastCvDate: userCvs[0]?.created_at || "", // cvs are sorted desc
        });
      });

      // Sort users by last CV date desc
      cvUsersList.sort(
        (a, b) =>
          new Date(b.lastCvDate).getTime() - new Date(a.lastCvDate).getTime(),
      );

      setCvUsers(cvUsersList);

      // Compute metrics
      const totalCvs = allCvs.length;
      const totalCreators = cvUsersList.length;
      const avgCvsPerCreator =
        totalCreators > 0 ? Number((totalCvs / totalCreators).toFixed(1)) : 0;

      // Compute template counts
      const counts: Record<string, number> = {};
      allCvs.forEach((c: any) => {
        const tId = c.template_id || "classic";
        counts[tId] = (counts[tId] || 0) + 1;
      });

      setTemplateCounts(counts);
      setMetrics({
        totalCvs,
        totalCreators,
        avgCvsPerCreator,
      });
    } catch (e: any) {
      console.error("Error fetching CV metrics:", e);
      setCvFetchError(
        e.message || "Erreur lors du chargement des métriques CV.",
      );
    } finally {
      setIsLoadingCvData(false);
    }
  };

  const handleSave = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError("");
    setSuccess("");

    setIsSaving(true);
    try {
      const endDate = config.cv_trial_end_date
        ? new Date(config.cv_trial_end_date).toISOString()
        : null;

      const { error: saveError } = await supabase
        .from("app_config")
        .update({
          cv_trial_active: config.cv_trial_active,
          cv_trial_end_date: endDate,
        })
        .eq("id", 1);

      if (saveError) throw saveError;

      setSuccess(
        config.cv_trial_active
          ? "Période d'essai activée. Le paywall CV est bypassé sur l'app en temps réel."
          : "Période d'essai désactivée. Le tarif normal (500 F CFA) est rétabli.",
      );
    } catch (e: any) {
      setError(e.message || "Erreur lors de l'enregistrement.");
    } finally {
      setIsSaving(false);
    }
  };

  const handleSavePricing = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setPricingError("");
    setPricingSuccess("");

    const premiumPrice = Number(pricingConfig.premium_price_cfa);
    const extraCvPrice = Number(pricingConfig.extra_cv_price_cfa);

    if (isNaN(premiumPrice) || premiumPrice < 0) {
      setPricingError("Le prix premium doit être un nombre positif ou nul.");
      return;
    }
    if (isNaN(extraCvPrice) || extraCvPrice < 0) {
      setPricingError(
        "Le prix du CV supplémentaire doit être un nombre positif ou nul.",
      );
      return;
    }

    setIsSavingPricing(true);
    try {
      const { error: saveError } = await supabase
        .from("app_config")
        .update({
          premium_price_cfa: premiumPrice,
          extra_cv_price_cfa: extraCvPrice,
        })
        .eq("id", 1);

      if (saveError) throw saveError;

      setPricingSuccess(
        "Tarification enregistrée avec succès. Les modifications sont appliquées sur l'application en temps réel.",
      );
    } catch (e: any) {
      setPricingError(
        e.message || "Erreur lors de l'enregistrement de la tarification.",
      );
    } finally {
      setIsSavingPricing(false);
    }
  };

  const handleSaveAi = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setAiError("");
    setAiSuccess("");

    setIsSavingAi(true);
    try {
      const endDate = aiConfig.ai_adapt_trial_end_date
        ? new Date(aiConfig.ai_adapt_trial_end_date).toISOString()
        : null;

      const { error: saveError } = await supabase
        .from("app_config")
        .update({
          ai_adapt_enabled: aiConfig.ai_adapt_enabled,
          ai_adapt_trial_active: aiConfig.ai_adapt_trial_active,
          ai_adapt_trial_end_date: endDate,
          ai_adapt_premium_limit: aiConfig.ai_adapt_premium_limit,
        })
        .eq("id", 1);

      if (saveError) throw saveError;

      setAiSuccess("Configuration du générateur IA enregistrée avec succès.");
    } catch (e: any) {
      setAiError(
        e.message || "Erreur lors de l'enregistrement de la configuration IA.",
      );
    } finally {
      setIsSavingAi(false);
    }
  };

  const handleTogglePremiumFeature = async (key: string, value: boolean) => {
    setPremiumFeatures((prev) => ({ ...prev, [key]: value }));
    try {
      await supabase
        .from("app_config")
        .update({ [key]: value })
        .eq("id", 1);
    } catch (e: any) {
      console.error("Error updating feature toggle:", e);
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
    const diff = Math.ceil(
      (end.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
    );
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

  const aiAdaptationStats = useMemo(() => {
    const adaptedCvEntries = cvUsers.flatMap((user) =>
      user.cvs
        .map((cv) => ({
          userId: user.id,
          userName: user.name,
          title: cv.title,
          createdAt: cv.createdAt,
          targetJobTitle: extractAdaptedJobTitle(cv.title),
        }))
        .filter((cv) => cv.targetJobTitle),
    );

    const usersWithAdaptation = new Set(
      adaptedCvEntries.map((entry) => entry.userId),
    );
    const jobCounts = adaptedCvEntries.reduce<Record<string, number>>(
      (acc, entry) => {
        const key = entry.targetJobTitle as string;
        acc[key] = (acc[key] || 0) + 1;
        return acc;
      },
      {},
    );

    const topJobs = Object.entries(jobCounts)
      .sort((a, b) => b[1] - a[1])
      .map(([jobTitle, count]) => ({ jobTitle, count }));

    return {
      totalAdaptedCvs: adaptedCvEntries.length,
      totalUsersWithAdaptation: usersWithAdaptation.size,
      totalTargetJobs: topJobs.length,
      topJobs,
      latestAdaptations: adaptedCvEntries
        .sort(
          (a, b) =>
            new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
        )
        .slice(0, 8),
    };
  }, [cvUsers]);

  useEffect(() => {
    if (focusSection !== "ai-adapt-stats" || isLoadingCvData) return;

    aiAdaptStatsRef.current?.scrollIntoView({
      behavior: "smooth",
      block: "start",
    });
    onFocusHandled?.();
  }, [focusSection, isLoadingCvData, onFocusHandled]);

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
                <FileText className="text-primary" size={22} /> Période d'essai
                — CV
              </h2>
              <p className="text-xs text-slate-500 mb-5">
                Bypassez le paywall du générateur de CV (500 F CFA) en temps
                réel pour tous les utilisateurs.
              </p>

              <form onSubmit={handleSave} className="space-y-5">
                {/* Toggle */}
                <div className="flex items-center justify-between p-3.5 bg-slate-50 rounded-xl border border-slate-200">
                  <div>
                    <p className="text-sm font-semibold text-slate-800">
                      Période d'essai gratuite
                    </p>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      {config.cv_trial_active
                        ? "Active — paywall bypassé sur l'app"
                        : "Inactive — tarif normal en vigueur"}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      setConfig((c) => ({
                        ...c,
                        cv_trial_active: !c.cv_trial_active,
                      }))
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
                      setConfig((c) => ({
                        ...c,
                        cv_trial_end_date: e.target.value,
                      }))
                    }
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all"
                  />
                </div>

                {/* Status indicator */}
                {config.cv_trial_end_date && (
                  <div
                    className={`flex items-start gap-2.5 px-3.5 py-2.5 rounded-xl text-xs ${
                      isExpired
                        ? "bg-red-50 text-red-600 border border-red-100"
                        : "bg-blue-50 text-blue-600 border border-blue-100"
                    }`}
                  >
                    <Info size={14} className="mt-0.5 shrink-0" />
                    {isExpired ? (
                      <span>
                        Le trial est <strong>dépassé</strong> — paywall actif
                        côté app.
                      </span>
                    ) : (
                      <span>
                        Il reste{" "}
                        <strong>
                          {days} jour{(days ?? 0) > 1 ? "s" : ""}
                        </strong>{" "}
                        avant la fin automatique.
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
                    "Enregistrer"
                  )}
                </button>
              </form>
            </div>

            <div className="bg-amber-50 border border-amber-100 rounded-xl p-3.5 mt-5 text-[11px] text-amber-700 flex gap-2.5">
              <Info size={16} className="shrink-0 mt-0.5 text-amber-500" />
              <div>
                <p className="font-semibold">Bypass en temps réel</p>
                <p className="text-amber-600 mt-0.5 leading-relaxed">
                  L'activation du toggle met à jour Supabase instantanément.
                  L'application Flutter s'adapte sans redémarrage via Supabase
                  Realtime.
                </p>
              </div>
            </div>
          </div>

          {/* Card 2: Tarification Premium & CV */}
          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between">
            <div>
              <h2 className="text-lg font-heading mb-1 flex items-center gap-2 text-slate-900">
                <TrendingUp className="text-cta" size={22} /> Tarification
                Premium & CV
              </h2>
              <p className="text-xs text-slate-500 mb-5">
                Ajustez le prix de l'abonnement Premium et des CV
                supplémentaires de l'application en Francs CFA.
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
                    "Enregistrer la tarification"
                  )}
                </button>
              </form>
            </div>
          </div>

          {/* Card: Gestion des Avantages Premium en temps réel */}
          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-4">
            <div>
              <h2 className="text-lg font-heading mb-1 flex items-center gap-2 text-slate-900">
                <Crown className="text-amber-500" size={22} /> Avantages Djorssi Premium en Temps Réel
              </h2>
              <p className="text-xs text-slate-500 mb-4">
                Activez ou désactivez les cartes d'avantages affichées aux utilisateurs sur la page d'abonnement Premium. Les modifications sont appliquées instantanément dans l'application mobile.
              </p>
              <div className="space-y-2.5">
                {[
                  { key: "feat_unlimited_swipes", label: "Swipes Illimités", desc: "Autorise les swipes quotidiens sans restriction" },
                  { key: "feat_unlocked_history", label: "Historique Déverrouillé", desc: "Permet de consulter l'historique complet des matches" },
                  { key: "feat_certified_badge", label: "Badge Candidat Certifié", desc: "Badge de confiance affiché aux recruteurs" },
                  { key: "feat_rewind", label: "Retour en Arrière (Rewind)", desc: "Annule le dernier swipe immédiatement" },
                  { key: "feat_email_alerts", label: "Alertes Emplois par Email", desc: "Envoi immédiat d'alertes lorsqu'un job est publié" },
                  { key: "feat_extra_cvs", label: "3 CV Professionnels Inclus", desc: "Création de jusqu'à 3 CV gratuitement" },
                  { key: "feat_ai_adaptation", label: "Adaptations CV par IA / Mois", desc: "Quota mensuel d'adaptations IA offertes" },
                ].map((feat) => {
                  const active = (premiumFeatures as any)[feat.key] ?? true;
                  return (
                    <div key={feat.key} className="flex items-center justify-between p-3 bg-slate-50 rounded-xl border border-slate-200">
                      <div>
                        <p className="text-sm font-semibold text-slate-800">{feat.label}</p>
                        <p className="text-[11px] text-slate-400 mt-0.5">{feat.desc}</p>
                      </div>
                      <button
                        type="button"
                        onClick={() => handleTogglePremiumFeature(feat.key, !active)}
                        className="focus:outline-none transition-transform active:scale-95"
                        aria-label={`Toggle ${feat.label}`}
                      >
                        {active ? (
                          <ToggleRight size={40} className="text-primary" />
                        ) : (
                          <ToggleLeft size={40} className="text-slate-300" />
                        )}
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Card unique: Packs de Crédits & Monétisation Adaptation IA */}
          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-6">
            {/* Partie 1: Statut & Période d'essai gratuit IA */}
            <div>
              <h2 className="text-lg font-heading mb-1 flex items-center gap-2 text-slate-900">
                <Coins className="text-amber-500" size={22} /> Packs de Crédits
                & Monétisation IA
              </h2>
              <p className="text-xs text-slate-500 mb-4">
                Gérez l'activation du générateur, le mode gratuit illimité et la
                grille tarifaire des packs de crédits en temps réel.
              </p>

              <form
                onSubmit={handleSaveAi}
                className="space-y-4 bg-slate-50/70 p-4 rounded-xl border border-slate-200/80"
              >
                <div className="flex items-center justify-between p-3 bg-white rounded-xl border border-slate-200">
                  <div>
                    <p className="text-sm font-semibold text-slate-800">
                      Générateur d'adaptation CV
                    </p>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      {aiConfig.ai_adapt_enabled
                        ? "Activé — le bouton Adapter mon CV est disponible dans l’app"
                        : "Désactivé — l’adaptation IA est bloquée côté mobile"}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      setAiConfig((c) => ({
                        ...c,
                        ai_adapt_enabled: !c.ai_adapt_enabled,
                      }))
                    }
                    className="focus:outline-none transition-transform active:scale-95"
                    aria-label="Activer ou désactiver le générateur d'adaptation CV"
                  >
                    {aiConfig.ai_adapt_enabled ? (
                      <ToggleRight size={44} className="text-primary" />
                    ) : (
                      <ToggleLeft size={44} className="text-slate-300" />
                    )}
                  </button>
                </div>

                {/* Toggle Période Lancement Gratuit */}
                <div className="flex items-center justify-between p-3 bg-white rounded-xl border border-slate-200">
                  <div>
                    <p className="text-sm font-semibold text-slate-800">
                      Essai gratuit illimité
                    </p>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      {aiConfig.ai_adapt_trial_active
                        ? "Activé — adaptations illimitées gratuites"
                        : "Désactivé — packs de crédits payants appliqués"}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      setAiConfig((c) => ({
                        ...c,
                        ai_adapt_trial_active: !c.ai_adapt_trial_active,
                      }))
                    }
                    className="focus:outline-none transition-transform active:scale-95"
                    aria-label="Activer/désactiver l'essai gratuit IA"
                  >
                    {aiConfig.ai_adapt_trial_active ? (
                      <ToggleRight size={44} className="text-primary" />
                    ) : (
                      <ToggleLeft size={44} className="text-slate-300" />
                    )}
                  </button>
                </div>

                {/* Date de fin de l'essai gratuit */}
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-slate-700 flex items-center gap-1.5">
                    <CalendarDays size={14} />
                    Date de fin de l'essai gratuit (optionnel)
                  </label>
                  <input
                    type="datetime-local"
                    value={aiConfig.ai_adapt_trial_end_date}
                    onChange={(e) =>
                      setAiConfig((c) => ({
                        ...c,
                        ai_adapt_trial_end_date: e.target.value,
                      }))
                    }
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all bg-white"
                  />
                </div>

                {/* Quota Mensuel Premium pour l'Adaptation IA */}
                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-slate-700 flex items-center gap-1.5">
                    <Sparkles size={14} className="text-amber-500" />
                    Quota mensuel d'adaptations IA incluses en Premium
                  </label>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    value={aiConfig.ai_adapt_premium_limit}
                    onChange={(e) =>
                      setAiConfig((c) => ({
                        ...c,
                        ai_adapt_premium_limit: parseInt(e.target.value) || 0,
                      }))
                    }
                    className="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none transition-all bg-white"
                  />
                  <p className="text-[11px] text-slate-400">
                    Nombre d'adaptations IA offertes chaque mois aux abonnés Premium (Défaut : 5).
                  </p>
                </div>

                {aiError && (
                  <div className="bg-red-50 text-red-600 px-3 py-2.5 rounded-xl flex items-center gap-2 text-xs">
                    <AlertCircle size={14} /> {aiError}
                  </div>
                )}
                {aiSuccess && (
                  <div className="bg-green-50 text-green-600 px-3 py-2.5 rounded-xl flex items-center gap-2 text-xs animate-in zoom-in duration-300">
                    <CheckCircle2 size={14} /> {aiSuccess}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isSavingAi}
                  className="w-full bg-primary text-white py-2.5 rounded-xl font-bold text-sm hover:shadow-lg hover:shadow-primary/20 active:scale-95 transition-all disabled:opacity-50 disabled:active:scale-100 flex items-center justify-center gap-2"
                >
                  {isSavingAi ? (
                    <>
                      <RefreshCw className="animate-spin" size={16} />
                      Enregistrement...
                    </>
                  ) : (
                    "Enregistrer le statut de l'essai gratuit"
                  )}
                </button>
              </form>
            </div>

            <hr className="border-slate-200" />

            {/* Partie 2: Grille des Packs de Crédits Adaptation IA */}
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <div>
                  <h3 className="text-sm font-bold uppercase tracking-wider text-slate-800 flex items-center gap-1.5">
                    <Sparkles className="text-primary" size={16} /> Grille des
                    Packs de Crédits
                  </h3>
                  <p className="text-xs text-slate-500">
                    Packs de crédits d'adaptation IA activables sur
                    l'application mobile.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setIsAddingPack(!isAddingPack)}
                  className="px-3 py-1.5 bg-primary/10 text-primary hover:bg-primary/20 border border-primary/20 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 shrink-0"
                >
                  {isAddingPack ? <X size={14} /> : <Plus size={14} />}
                  {isAddingPack ? "Fermer" : "Ajouter un pack"}
                </button>
              </div>

              {packError && (
                <div className="bg-red-50 text-red-600 px-3.5 py-2.5 rounded-xl flex items-center gap-2 text-xs">
                  <AlertCircle size={14} className="shrink-0" /> {packError}
                </div>
              )}
              {packSuccess && (
                <div className="bg-green-50 text-green-600 px-3.5 py-2.5 rounded-xl flex items-center gap-2 text-xs animate-in zoom-in duration-300">
                  <CheckCircle2 size={14} className="shrink-0" /> {packSuccess}
                </div>
              )}

              {/* Formulaire d'ajout de pack */}
              {isAddingPack && (
                <form
                  onSubmit={handleCreatePack}
                  className="bg-slate-50 p-4 rounded-xl border border-slate-200 space-y-4 animate-in fade-in slide-in-from-top-2 duration-300"
                >
                  <p className="text-xs font-bold text-slate-800 uppercase tracking-wider flex items-center gap-1.5">
                    <Plus size={14} className="text-primary" /> Créer un nouveau
                    pack de crédits
                  </p>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <div>
                      <label className="text-[11px] font-semibold text-slate-700">
                        Identifiant (ID unique)
                      </label>
                      <input
                        type="text"
                        placeholder="ex: pack_flash"
                        value={newPack.id || ""}
                        onChange={(e) =>
                          setNewPack((p) => ({ ...p, id: e.target.value }))
                        }
                        className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-primary/20 bg-white"
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-semibold text-slate-700">
                        Nom du pack
                      </label>
                      <input
                        type="text"
                        placeholder="ex: Pack Starter"
                        value={newPack.name || ""}
                        onChange={(e) =>
                          setNewPack((p) => ({ ...p, name: e.target.value }))
                        }
                        className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-primary/20 bg-white"
                        required
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-semibold text-slate-700">
                        Nombre de Crédits
                      </label>
                      <input
                        type="number"
                        min={1}
                        value={newPack.credits || 1}
                        onChange={(e) =>
                          setNewPack((p) => ({
                            ...p,
                            credits: parseInt(e.target.value, 10) || 1,
                          }))
                        }
                        className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-primary/20 bg-white"
                        required
                      />
                    </div>
                    <div>
                      <label className="text-[11px] font-semibold text-slate-700">
                        Prix (F CFA)
                      </label>
                      <input
                        type="number"
                        min={0}
                        value={newPack.price_cfa || 500}
                        onChange={(e) =>
                          setNewPack((p) => ({
                            ...p,
                            price_cfa: parseInt(e.target.value, 10) || 0,
                          }))
                        }
                        className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-primary/20 bg-white"
                        required
                      />
                    </div>
                    <div className="md:col-span-2">
                      <label className="text-[11px] font-semibold text-slate-700">
                        Badge / Accroche (optionnel)
                      </label>
                      <input
                        type="text"
                        placeholder="ex: Pour postuler sur un coup de cœur"
                        value={newPack.badge || ""}
                        onChange={(e) =>
                          setNewPack((p) => ({ ...p, badge: e.target.value }))
                        }
                        className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-primary/20 bg-white"
                      />
                    </div>
                  </div>

                  <div className="flex items-center gap-4 pt-1">
                    <label className="flex items-center gap-1.5 text-xs text-slate-700 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={!!newPack.is_recommended}
                        onChange={(e) =>
                          setNewPack((p) => ({
                            ...p,
                            is_recommended: e.target.checked,
                          }))
                        }
                        className="rounded text-primary focus:ring-primary"
                      />
                      Pack Recommandé ⭐
                    </label>
                    <label className="flex items-center gap-1.5 text-xs text-slate-700 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={newPack.is_active ?? true}
                        onChange={(e) =>
                          setNewPack((p) => ({
                            ...p,
                            is_active: e.target.checked,
                          }))
                        }
                        className="rounded text-primary focus:ring-primary"
                      />
                      Actif dès la création
                    </label>
                  </div>

                  <div className="flex justify-end gap-2 pt-2">
                    <button
                      type="button"
                      onClick={() => setIsAddingPack(false)}
                      className="px-3 py-1.5 text-xs font-semibold text-slate-500 hover:text-slate-700"
                    >
                      Annuler
                    </button>
                    <button
                      type="submit"
                      className="px-4 py-1.5 bg-primary text-white rounded-lg text-xs font-bold hover:shadow-md transition-all"
                    >
                      Enregistrer le pack
                    </button>
                  </div>
                </form>
              )}

              {/* Liste des Packs de Crédits */}
              {isLoadingPacks ? (
                <div className="py-8 flex items-center justify-center text-slate-400 gap-2 text-xs">
                  <RefreshCw className="animate-spin" size={16} /> Chargement
                  des packs...
                </div>
              ) : creditPacks.length === 0 ? (
                <div className="py-8 text-center text-slate-400 text-xs italic">
                  Aucun pack de crédits configuré. Cliquez sur "Ajouter un pack"
                  pour commencer.
                </div>
              ) : (
                <div className="space-y-3">
                  {creditPacks.map((pack) => {
                    const isEditing = editingPackId === pack.id;
                    return (
                      <div
                        key={pack.id}
                        className={`p-4 rounded-xl border transition-all ${
                          pack.is_active
                            ? pack.is_recommended
                              ? "bg-amber-50/40 border-amber-200 shadow-sm"
                              : "bg-slate-50/70 border-slate-200"
                            : "bg-slate-100/60 border-slate-200 opacity-60"
                        }`}
                      >
                        {isEditing ? (
                          /* Formulaire d'édition du pack */
                          <div className="space-y-3">
                            <div className="flex justify-between items-center pb-2 border-b border-slate-200">
                              <span className="text-xs font-bold text-slate-800">
                                Édition du pack #{pack.id}
                              </span>
                              <button
                                type="button"
                                onClick={() => setEditingPackId(null)}
                                className="text-slate-400 hover:text-slate-600"
                              >
                                <X size={16} />
                              </button>
                            </div>
                            <div className="grid grid-cols-2 gap-2.5 text-xs">
                              <div>
                                <label className="font-semibold text-slate-700 text-[10px]">
                                  Nom du pack
                                </label>
                                <input
                                  type="text"
                                  value={editingPack.name || ""}
                                  onChange={(e) =>
                                    setEditingPack((p) => ({
                                      ...p,
                                      name: e.target.value,
                                    }))
                                  }
                                  className="w-full px-2.5 py-1.5 border border-slate-200 rounded-lg bg-white"
                                />
                              </div>
                              <div>
                                <label className="font-semibold text-slate-700 text-[10px]">
                                  Prix (F CFA)
                                </label>
                                <input
                                  type="number"
                                  min={0}
                                  value={editingPack.price_cfa || 0}
                                  onChange={(e) =>
                                    setEditingPack((p) => ({
                                      ...p,
                                      price_cfa:
                                        parseInt(e.target.value, 10) || 0,
                                    }))
                                  }
                                  className="w-full px-2.5 py-1.5 border border-slate-200 rounded-lg bg-white"
                                />
                              </div>
                              <div>
                                <label className="font-semibold text-slate-700 text-[10px]">
                                  Nombre de Crédits
                                </label>
                                <input
                                  type="number"
                                  min={1}
                                  value={editingPack.credits || 1}
                                  onChange={(e) =>
                                    setEditingPack((p) => ({
                                      ...p,
                                      credits:
                                        parseInt(e.target.value, 10) || 1,
                                    }))
                                  }
                                  className="w-full px-2.5 py-1.5 border border-slate-200 rounded-lg bg-white"
                                />
                              </div>
                              <div>
                                <label className="font-semibold text-slate-700 text-[10px]">
                                  Ordre d'affichage
                                </label>
                                <input
                                  type="number"
                                  min={1}
                                  value={editingPack.display_order || 1}
                                  onChange={(e) =>
                                    setEditingPack((p) => ({
                                      ...p,
                                      display_order:
                                        parseInt(e.target.value, 10) || 1,
                                    }))
                                  }
                                  className="w-full px-2.5 py-1.5 border border-slate-200 rounded-lg bg-white"
                                />
                              </div>
                              <div className="col-span-2">
                                <label className="font-semibold text-slate-700 text-[10px]">
                                  Badge / Description
                                </label>
                                <input
                                  type="text"
                                  value={editingPack.badge || ""}
                                  onChange={(e) =>
                                    setEditingPack((p) => ({
                                      ...p,
                                      badge: e.target.value,
                                    }))
                                  }
                                  className="w-full px-2.5 py-1.5 border border-slate-200 rounded-lg bg-white"
                                />
                              </div>
                              <div className="col-span-2 flex items-center gap-4 pt-1">
                                <label className="flex items-center gap-1.5 text-xs text-slate-700 cursor-pointer">
                                  <input
                                    type="checkbox"
                                    checked={!!editingPack.is_recommended}
                                    onChange={(e) =>
                                      setEditingPack((p) => ({
                                        ...p,
                                        is_recommended: e.target.checked,
                                      }))
                                    }
                                    className="rounded text-primary"
                                  />
                                  Pack Recommandé ⭐
                                </label>
                              </div>
                            </div>
                            <div className="flex justify-end gap-2 pt-2">
                              <button
                                type="button"
                                onClick={() => setEditingPackId(null)}
                                className="px-3 py-1.5 text-xs font-semibold text-slate-500"
                              >
                                Annuler
                              </button>
                              <button
                                type="button"
                                onClick={() => handleSaveEditPack(pack.id)}
                                className="px-3.5 py-1.5 bg-primary text-white rounded-lg text-xs font-bold flex items-center gap-1"
                              >
                                <Check size={14} /> Enregistrer
                              </button>
                            </div>
                          </div>
                        ) : (
                          /* Vue normale du pack */
                          <div className="flex items-center justify-between gap-3">
                            <div className="space-y-1 min-w-0 flex-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <h3 className="font-bold text-slate-900 text-sm">
                                  {pack.name}
                                </h3>
                                {pack.is_recommended && (
                                  <span className="px-2 py-0.5 bg-amber-500/10 text-amber-600 border border-amber-500/30 rounded-md text-[10px] font-black uppercase tracking-wider flex items-center gap-1">
                                    <Sparkles size={10} /> Recommandé
                                  </span>
                                )}
                                <span
                                  className={`px-2 py-0.5 rounded-md text-[10px] font-bold ${
                                    pack.is_active
                                      ? "bg-emerald-100 text-emerald-700 border border-emerald-200"
                                      : "bg-slate-200 text-slate-500"
                                  }`}
                                >
                                  {pack.is_active ? "Actif" : "Inactif"}
                                </span>
                              </div>

                              <p className="text-xs text-slate-600 font-medium flex items-center gap-2">
                                <span className="font-bold text-primary text-sm">
                                  {pack.credits} crédits
                                </span>
                                <span>•</span>
                                <span className="font-bold text-slate-900">
                                  {pack.price_cfa.toLocaleString("fr-FR")} F CFA
                                </span>
                              </p>

                              {pack.badge && (
                                <p className="text-[11px] text-slate-500 italic">
                                  "{pack.badge}"
                                </p>
                              )}
                            </div>

                            <div className="flex items-center gap-2 shrink-0">
                              {/* Toggle ON/OFF */}
                              <button
                                type="button"
                                onClick={() => togglePackActive(pack)}
                                className="focus:outline-none transition-transform active:scale-95 p-1"
                                title={
                                  pack.is_active
                                    ? "Désactiver le pack"
                                    : "Activer le pack"
                                }
                              >
                                {pack.is_active ? (
                                  <ToggleRight
                                    size={36}
                                    className="text-emerald-500"
                                  />
                                ) : (
                                  <ToggleLeft
                                    size={36}
                                    className="text-slate-300"
                                  />
                                )}
                              </button>

                              {/* Edit Button */}
                              <button
                                type="button"
                                onClick={() => startEditPack(pack)}
                                className="p-1.5 text-slate-500 hover:text-primary hover:bg-slate-100 rounded-lg transition-colors"
                                title="Modifier le pack"
                              >
                                <Edit3 size={15} />
                              </button>

                              {/* Delete Button */}
                              <button
                                type="button"
                                onClick={() => handleDeletePack(pack.id)}
                                className="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                                title="Supprimer le pack"
                              >
                                <Trash2 size={15} />
                              </button>
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: CV Generation Metrics (7/12 width on lg) */}
        <div className="lg:col-span-7 flex flex-col justify-between bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <div>
            <div className="flex justify-between items-center mb-6">
              <div>
                <h2 className="text-lg font-heading text-slate-900 flex items-center gap-2">
                  <TrendingUp className="text-cta" size={22} /> Métriques
                  d'Utilisation
                </h2>
                <p className="text-xs text-slate-500">
                  Statistiques globales sur la création de CV.
                </p>
              </div>
              <button
                onClick={fetchCvData}
                disabled={isLoadingCvData}
                className="p-1.5 text-slate-400 hover:text-slate-600 bg-slate-50 border border-slate-200 rounded-lg transition-all active:scale-95 disabled:opacity-50"
                title="Rafraîchir les métriques"
              >
                <RefreshCw
                  size={16}
                  className={isLoadingCvData ? "animate-spin" : ""}
                />
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
                      <span className="text-[10px] font-bold uppercase tracking-wider">
                        CV Générés
                      </span>
                      <FileText size={16} className="text-primary" />
                    </div>
                    <p className="text-2xl font-black text-slate-950">
                      {metrics.totalCvs}
                    </p>
                    <p className="text-[10px] text-slate-400 mt-1">
                      Total de CVs créés
                    </p>
                  </div>

                  <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                    <div className="flex items-center justify-between text-slate-400 mb-1">
                      <span className="text-[10px] font-bold uppercase tracking-wider">
                        Créateurs
                      </span>
                      <Users size={16} className="text-cta" />
                    </div>
                    <p className="text-2xl font-black text-slate-950">
                      {metrics.totalCreators}
                    </p>
                    <p className="text-[10px] text-slate-400 mt-1">
                      Utilisateurs uniques
                    </p>
                  </div>

                  <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                    <div className="flex items-center justify-between text-slate-400 mb-1">
                      <span className="text-[10px] font-bold uppercase tracking-wider">
                        Moyenne
                      </span>
                      <Award size={16} className="text-purple-600" />
                    </div>
                    <p className="text-2xl font-black text-slate-950">
                      {metrics.avgCvsPerCreator}
                    </p>
                    <p className="text-[10px] text-slate-400 mt-1">
                      CVs par utilisateur
                    </p>
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
                      const percentage =
                        metrics.totalCvs > 0
                          ? Math.round((count / metrics.totalCvs) * 100)
                          : 0;
                      return (
                        <div key={templateId} className="space-y-1">
                          <div className="flex justify-between text-[11px] font-bold text-slate-600">
                            <span>{templateLabels[templateId]}</span>
                            <span>
                              {count} ({percentage}%)
                            </span>
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

      <div
        ref={aiAdaptStatsRef}
        className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden"
      >
        <div className="p-6 border-b border-slate-200 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h3 className="text-lg font-heading text-slate-900 flex items-center gap-2">
              <Sparkles className="text-purple-600" size={20} />
              Adaptations IA par poste
            </h3>
            <p className="text-xs text-slate-500">
              Suivi des CV adaptés automatiquement selon le poste ciblé.
            </p>
          </div>

          <button
            onClick={fetchCvData}
            disabled={isLoadingCvData}
            className="p-2 text-slate-400 hover:text-slate-600 bg-slate-50 border border-slate-200 rounded-lg transition-all active:scale-95 disabled:opacity-50"
            title="Rafraîchir les données d'adaptation IA"
          >
            <RefreshCw
              size={16}
              className={isLoadingCvData ? "animate-spin" : ""}
            />
          </button>
        </div>

        {cvFetchError ? (
          <div className="p-6">
            <div className="bg-red-50 text-red-600 p-4 rounded-xl flex items-center gap-2 text-sm">
              <AlertCircle size={16} /> {cvFetchError}
            </div>
          </div>
        ) : isLoadingCvData ? (
          <div className="flex flex-col items-center justify-center py-16 text-slate-400 gap-2">
            <RefreshCw className="animate-spin" size={24} />
            <p className="text-xs">Chargement des adaptations IA...</p>
          </div>
        ) : (
          <div className="p-6 space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                <div className="flex items-center justify-between text-slate-400 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider">
                    CV adaptés
                  </span>
                  <Sparkles size={16} className="text-purple-600" />
                </div>
                <p className="text-2xl font-black text-slate-950">
                  {aiAdaptationStats.totalAdaptedCvs}
                </p>
                <p className="text-[10px] text-slate-400 mt-1">
                  Total des adaptations détectées
                </p>
              </div>

              <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                <div className="flex items-center justify-between text-slate-400 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider">
                    Utilisateurs
                  </span>
                  <Users size={16} className="text-cta" />
                </div>
                <p className="text-2xl font-black text-slate-950">
                  {aiAdaptationStats.totalUsersWithAdaptation}
                </p>
                <p className="text-[10px] text-slate-400 mt-1">
                  Personnes ayant adapté leur CV
                </p>
              </div>

              <div className="bg-slate-50 border border-slate-200 p-4 rounded-xl">
                <div className="flex items-center justify-between text-slate-400 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider">
                    Postes ciblés
                  </span>
                  <Briefcase size={16} className="text-primary" />
                </div>
                <p className="text-2xl font-black text-slate-950">
                  {aiAdaptationStats.totalTargetJobs}
                </p>
                <p className="text-[10px] text-slate-400 mt-1">
                  Intitulés de poste distincts
                </p>
              </div>
            </div>

            {aiAdaptationStats.totalAdaptedCvs === 0 ? (
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-8 text-center">
                <Sparkles size={28} className="mx-auto text-slate-300 mb-3" />
                <p className="text-sm font-semibold text-slate-600">
                  Aucune adaptation IA détectée pour le moment.
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
                <div className="xl:col-span-2">
                  <div className="border border-slate-200 rounded-xl overflow-hidden">
                    <div className="grid grid-cols-[1fr_auto_auto] gap-4 bg-slate-50 px-4 py-3 text-[10px] font-black uppercase tracking-widest text-slate-500 border-b border-slate-200">
                      <span>Poste ciblé</span>
                      <span>CV adaptés</span>
                      <span>Part</span>
                    </div>

                    <div className="divide-y divide-slate-100">
                      {aiAdaptationStats.topJobs.slice(0, 12).map((job) => {
                        const percentage = aiAdaptationStats.totalAdaptedCvs
                          ? Math.round(
                              (job.count / aiAdaptationStats.totalAdaptedCvs) *
                                100,
                            )
                          : 0;

                        return (
                          <div
                            key={job.jobTitle}
                            className="grid grid-cols-[1fr_auto_auto] gap-4 items-center px-4 py-3"
                          >
                            <div className="min-w-0">
                              <p className="text-sm font-bold text-slate-800 truncate">
                                {job.jobTitle}
                              </p>
                            </div>
                            <span className="text-sm font-black text-primary">
                              {job.count}
                            </span>
                            <span className="text-xs font-bold text-slate-500">
                              {percentage}%
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                </div>

                <div className="space-y-3">
                  <h4 className="text-xs font-bold text-slate-400 uppercase tracking-widest">
                    Dernières adaptations
                  </h4>
                  <div className="space-y-3">
                    {aiAdaptationStats.latestAdaptations.map((adaptation) => (
                      <div
                        key={`${adaptation.userId}-${adaptation.createdAt}-${adaptation.title}`}
                        className="bg-slate-50 border border-slate-200 rounded-xl p-4"
                      >
                        <p className="text-sm font-bold text-slate-900">
                          {adaptation.userName}
                        </p>
                        <p className="text-xs text-slate-600 mt-1">
                          Poste :{" "}
                          <span className="font-semibold">
                            {adaptation.targetJobTitle}
                          </span>
                        </p>
                        <p className="text-[11px] text-slate-400 mt-2">
                          {new Date(adaptation.createdAt).toLocaleDateString(
                            "fr-FR",
                            {
                              day: "numeric",
                              month: "short",
                              year: "numeric",
                              hour: "2-digit",
                              minute: "2-digit",
                            },
                          )}
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Lower Section: Searchable Users & CVs list */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="p-6 border-b border-slate-200 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h3 className="text-lg font-heading text-slate-900">
              Utilisateurs du Générateur de CV
            </h3>
            <p className="text-xs text-slate-500">
              Consultez qui utilise le service CV de l'application.
            </p>
          </div>

          <div className="relative w-full md:w-80">
            <Search
              className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
              size={16}
            />
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
                                user.isPremium
                                  ? "bg-cta text-white shadow-sm"
                                  : "bg-slate-100 text-slate-500"
                              }`}
                            >
                              {user.name.charAt(0)}
                            </div>
                            <div>
                              <p className="font-bold text-slate-900 leading-none text-sm">
                                {user.name}
                              </p>
                              <p className="text-[10px] text-slate-400 mt-1 font-mono uppercase">
                                #{user.id.substring(0, 8)}
                              </p>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <p className="text-xs font-semibold text-slate-700">
                            {user.phone}
                          </p>
                        </td>
                        <td className="px-6 py-4">
                          <span
                            className={`px-2.5 py-0.5 rounded-lg text-[9px] font-black uppercase tracking-tight ${
                              user.isPremium
                                ? "bg-cta text-white shadow-sm shadow-cta/20"
                                : "bg-slate-100 text-slate-500"
                            }`}
                          >
                            {user.isPremium ? "Premium" : "Standard"}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-center">
                          <span className="px-2 py-0.5 bg-primary/10 text-primary border border-primary/20 rounded-md text-xs font-bold">
                            {user.cvs.length}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          <p className="text-xs text-slate-500 font-medium">
                            {new Date(user.lastCvDate).toLocaleDateString(
                              "fr-FR",
                              {
                                day: "numeric",
                                month: "short",
                                year: "numeric",
                              },
                            )}
                          </p>
                        </td>
                        <td className="px-6 py-4 text-right">
                          <button
                            onClick={() => toggleExpandUser(user.id)}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 rounded-lg text-xs font-bold text-slate-600 bg-white hover:bg-slate-50 transition-colors"
                          >
                            <Eye size={12} />
                            {isExpanded ? "Masquer" : "Voir CVs"}
                            {isExpanded ? (
                              <ChevronUp size={12} />
                            ) : (
                              <ChevronDown size={12} />
                            )}
                          </button>
                        </td>
                      </tr>

                      {/* Expanded Section showing individual CV details */}
                      {isExpanded && (
                        <tr className="bg-slate-50/30">
                          <td
                            colSpan={6}
                            className="px-8 py-5 border-t border-b border-slate-200/50"
                          >
                            <div className="space-y-4">
                              <div className="flex justify-between items-center">
                                <p className="text-xs font-black text-slate-400 uppercase tracking-widest">
                                  Détails des CV créés par l'utilisateur (
                                  {user.cvs.length})
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
                                      <div
                                        className="h-3 w-full"
                                        style={{
                                          backgroundColor: cv.primaryColor,
                                        }}
                                      />
                                      <div
                                        className="h-2.5 w-full"
                                        style={{
                                          backgroundColor: cv.secondaryColor,
                                        }}
                                      />
                                      <div className="flex-1 bg-slate-50 flex items-center justify-center">
                                        <FileText
                                          size={16}
                                          className="text-slate-400"
                                        />
                                      </div>
                                    </div>
                                    <div className="space-y-1.5 flex-1 min-w-0">
                                      <p className="font-bold text-slate-800 text-sm truncate">
                                        {cv.title}
                                      </p>
                                      <div className="flex flex-wrap gap-2 items-center">
                                        <span className="px-2 py-0.5 bg-slate-100 text-[10px] font-bold rounded text-slate-600">
                                          Modèle :{" "}
                                          {templateLabels[cv.templateId] ||
                                            cv.templateId}
                                        </span>
                                        <span className="text-[10px] text-slate-400">
                                          Créé le{" "}
                                          {new Date(
                                            cv.createdAt,
                                          ).toLocaleDateString("fr-FR", {
                                            day: "numeric",
                                            month: "short",
                                            year: "numeric",
                                            hour: "2-digit",
                                            minute: "2-digit",
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
                      <FileText
                        size={40}
                        className="mx-auto text-slate-200 mb-2"
                      />
                      <p className="text-slate-400 italic">
                        Aucun créateur de CV trouvé.
                      </p>
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
