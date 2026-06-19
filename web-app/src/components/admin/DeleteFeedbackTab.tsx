import React, { useEffect, useState } from 'react';
import {
  UserX,
  Search,
  RefreshCw,
  AlertCircle,
  Trash2,
  Calendar,
  Phone,
  Mail,
  MessageSquare,
  BarChart3,
  CheckCircle2
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface DeleteFeedback {
  id: string;
  user_id: string | null;
  phone_number: string | null;
  email: string | null;
  reason: string;
  feedback: string | null;
  created_at: string;
}

const DeleteFeedbackTab: React.FC = () => {
  const [feedbacks, setFeedbacks] = useState<DeleteFeedback[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [reasonFilter, setReasonFilter] = useState('all');

  useEffect(() => {
    fetchFeedbacks();
  }, []);

  const fetchFeedbacks = async () => {
    setIsLoading(true);
    setError('');
    try {
      const { data, error: fetchError } = await supabase
        .from('delete_account_feedback')
        .select('*')
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;
      setFeedbacks(data || []);
    } catch (err: any) {
      console.error('Error loading deletion feedback:', err);
      setError(err.message || 'Impossible de charger les retours de suppression.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDeleteFeedback = async (id: string) => {
    if (!window.confirm('Voulez-vous vraiment supprimer cet enregistrement de feedback ?')) return;

    setError('');
    setSuccess('');
    try {
      const { error: deleteError } = await supabase
        .from('delete_account_feedback')
        .delete()
        .eq('id', id);

      if (deleteError) throw deleteError;

      setSuccess('Retour de suppression supprimé avec succès.');
      setFeedbacks(prev => prev.filter(f => f.id !== id));
    } catch (err: any) {
      setError(err.message || 'Erreur lors de la suppression de l\'enregistrement.');
    }
  };

  // Compute Statistics
  const totalCount = feedbacks.length;
  const reasonStats: Record<string, number> = {};
  feedbacks.forEach(f => {
    reasonStats[f.reason] = (reasonStats[f.reason] || 0) + 1;
  });

  const uniqueReasons = Array.from(new Set(feedbacks.map(f => f.reason)));

  const filteredFeedbacks = feedbacks.filter(f => {
    const matchesSearch =
      (f.email || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (f.phone_number || '').includes(searchTerm) ||
      (f.feedback || '').toLowerCase().includes(searchTerm.toLowerCase());

    const matchesReason = reasonFilter === 'all' || f.reason === reasonFilter;

    return matchesSearch && matchesReason;
  });

  return (
    <div className="max-w-6xl mx-auto space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-12">
      {/* Header and Controls */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h2 className="text-xl font-heading flex items-center gap-2 text-slate-900">
            <UserX className="text-red-500" size={24} /> Retours de Suppression de Compte
          </h2>
          <p className="text-sm text-slate-500">
            Suivez les motifs et les avis des utilisateurs qui choisissent de fermer leur compte Djorssi Match.
          </p>
        </div>
        
        <button
          onClick={fetchFeedbacks}
          disabled={isLoading}
          className="flex items-center gap-2 px-4 py-2 border border-slate-200 rounded-xl text-sm font-bold bg-slate-50 hover:bg-slate-100 transition-colors disabled:opacity-50"
        >
          <RefreshCw size={16} className={isLoading ? 'animate-spin' : ''} />
          Rafraîchir
        </button>
      </div>

      {/* Stats Panel */}
      {totalCount > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between">
            <div>
              <span className="text-xs font-black text-slate-400 uppercase tracking-widest">Total Désinscriptions</span>
              <h3 className="text-3xl font-black text-slate-800 mt-2">{totalCount}</h3>
            </div>
            <p className="text-xs text-slate-500 mt-4">Comptes supprimés avec feedback enregistré.</p>
          </div>

          <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm md:col-span-2">
            <h4 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-4 flex items-center gap-1.5">
              <BarChart3 size={14} className="text-primary" /> Répartition des motifs
            </h4>
            <div className="space-y-3">
              {Object.entries(reasonStats)
                .sort((a, b) => b[1] - a[1])
                .map(([reason, count]) => {
                  const percentage = ((count / totalCount) * 100).toFixed(0);
                  return (
                    <div key={reason} className="space-y-1">
                      <div className="flex justify-between text-xs font-bold text-slate-700">
                        <span className="truncate max-w-[85%]">{reason}</span>
                        <span>{count} ({percentage}%)</span>
                      </div>
                      <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                        <div
                          className="bg-primary h-full rounded-full transition-all duration-550"
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

      {/* Filters & Search */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm grid grid-cols-1 md:grid-cols-12 gap-4">
        {/* Search */}
        <div className="md:col-span-7 relative">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Rechercher par email, téléphone ou commentaire..."
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all"
          />
        </div>

        {/* Reason Filter */}
        <div className="md:col-span-5">
          <select
            value={reasonFilter}
            onChange={(e) => setReasonFilter(e.target.value)}
            className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
          >
            <option value="all">Tous les motifs</option>
            {uniqueReasons.map(r => (
              <option key={r} value={r}>{r}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Messages / Notifications */}
      {error && (
        <div className="bg-red-50 text-red-600 px-4 py-3 rounded-xl flex items-center gap-2 text-sm shadow-sm">
          <AlertCircle size={16} /> {error}
        </div>
      )}
      {success && (
        <div className="bg-green-50 text-green-600 px-4 py-3 rounded-xl flex items-center gap-2 text-sm shadow-sm animate-in zoom-in duration-300">
          <CheckCircle2 size={16} /> {success}
        </div>
      )}

      {/* Feedbacks List */}
      {isLoading ? (
        <div className="flex flex-col items-center justify-center py-24 text-slate-400 gap-3">
          <RefreshCw className="animate-spin" size={36} />
          <p className="text-sm">Chargement des retours de suppression...</p>
        </div>
      ) : filteredFeedbacks.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-16 text-center shadow-sm">
          <UserX size={44} className="mx-auto text-slate-200 mb-3" />
          <p className="text-slate-500 font-semibold">Aucun retour enregistré.</p>
          <p className="text-xs text-slate-400 mt-1">Les utilisateurs n'ont pas encore supprimé de compte ou modifié leurs filtres.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredFeedbacks.map((item) => (
            <div
              key={item.id}
              className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm transition-all hover:border-slate-300"
            >
              {/* Header */}
              <div className="flex flex-wrap justify-between items-start gap-4 mb-4">
                <div className="space-y-1">
                  <span className="px-2.5 py-1 rounded-lg text-xs font-black uppercase tracking-wider bg-red-50 text-red-600 border border-red-100">
                    {item.reason}
                  </span>
                  <div className="flex flex-wrap items-center gap-4 text-xs text-slate-500 mt-2 font-medium">
                    {item.email && (
                      <span className="flex items-center gap-1.5">
                        <Mail size={13} className="text-slate-400" />
                        {item.email}
                      </span>
                    )}
                    {item.phone_number && (
                      <span className="flex items-center gap-1.5">
                        <Phone size={13} className="text-slate-400" />
                        {item.phone_number}
                      </span>
                    )}
                    <span className="flex items-center gap-1.5 font-mono text-[11px] text-slate-400">
                      <Calendar size={13} />
                      {new Date(item.created_at).toLocaleDateString('fr-FR', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </span>
                  </div>
                </div>

                <button
                  onClick={() => handleDeleteFeedback(item.id)}
                  className="p-1.5 text-slate-400 hover:text-red-500 rounded-lg hover:bg-slate-50 transition-colors"
                  title="Supprimer l'enregistrement"
                >
                  <Trash2 size={16} />
                </button>
              </div>

              {/* Feedback Content */}
              {item.feedback ? (
                <div className="bg-slate-50 border border-slate-100 rounded-xl p-4 flex gap-3">
                  <MessageSquare size={16} className="text-slate-400 shrink-0 mt-0.5" />
                  <p className="text-sm text-slate-700 whitespace-pre-wrap leading-relaxed">
                    {item.feedback}
                  </p>
                </div>
              ) : (
                <p className="text-xs text-slate-400 italic">Aucun commentaire supplémentaire laissé.</p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default DeleteFeedbackTab;
