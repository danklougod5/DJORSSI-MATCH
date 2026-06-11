import React, { useEffect, useState } from 'react';
import {
  MessageSquare,
  Search,
  RefreshCw,
  AlertCircle,
  CheckCircle2,
  Send,
  CornerDownRight,
  Filter,
  Trash2
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface SupportMessage {
  id: string;
  user_id: string;
  message_type: 'question' | 'suggestion';
  content: string;
  admin_reply: string | null;
  replied_at: string | null;
  created_at: string;
  user_name?: string;
  user_phone?: string;
}

const SupportTab: React.FC = () => {
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Filtering states
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState<'all' | 'question' | 'suggestion'>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'replied'>('all');

  // Reply text states indexed by message id
  const [replyTexts, setReplyTexts] = useState<Record<string, string>>({});
  const [submittingReplyId, setSubmittingReplyId] = useState<string | null>(null);

  useEffect(() => {
    fetchMessages();
  }, []);

  const fetchMessages = async () => {
    setIsLoading(true);
    setError('');
    try {
      const { data, error: fetchError } = await supabase
        .from('support_messages')
        .select('*')
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;

      if (!data || data.length === 0) {
        setMessages([]);
        return;
      }

      // Fetch profile info for each user
      const userIds = Array.from(new Set(data.map((m: any) => m.user_id)));
      const { data: profiles, error: profilesError } = await supabase
        .from('profiles')
        .select('id, full_name, phone_number')
        .in('id', userIds);

      if (profilesError) throw profilesError;

      const profilesMap = (profiles || []).reduce((acc: any, p: any) => {
        acc[p.id] = p;
        return acc;
      }, {});

      const combined: SupportMessage[] = data.map((m: any) => ({
        ...m,
        user_name: profilesMap[m.user_id]?.full_name || 'Utilisateur Anonyme',
        user_phone: profilesMap[m.user_id]?.phone_number || '-'
      }));

      setMessages(combined);
    } catch (err: any) {
      console.error('Error loading support messages:', err);
      setError(err.message || 'Impossible de charger les messages de support.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSendReply = async (messageId: string) => {
    const replyText = replyTexts[messageId]?.trim();
    if (!replyText) return;

    setSubmittingReplyId(messageId);
    setError('');
    setSuccess('');

    try {
      const msg = messages.find(m => m.id === messageId);
      const userId = msg?.user_id;

      const { error: updateError } = await supabase
        .from('support_messages')
        .update({
          admin_reply: replyText,
          replied_at: new Date().toISOString(),
          is_read: false // Mark as unread for the user
        })
        .eq('id', messageId);

      if (updateError) throw updateError;

      setSuccess('Votre réponse a été envoyée avec succès.');
      
      // Update local state
      setMessages(prev =>
        prev.map(m =>
          m.id === messageId
            ? { ...m, admin_reply: replyText, replied_at: new Date().toISOString() }
            : m
        )
      );

      // Clear the reply input
      setReplyTexts(prev => ({ ...prev, [messageId]: '' }));

      // Trigger push notification to user
      if (userId) {
        supabase.functions.invoke('send-broadcast-notification', {
          body: {
            title: "Réponse à votre message 💬",
            message: "L'équipe Djorssi-Match a répondu à votre question/suggestion.",
            target: userId
          }
        }).catch((err: any) => console.error("Error sending notification:", err));
      }
    } catch (err: any) {
      setError(err.message || 'Erreur lors de l\'envoi de la réponse.');
    } finally {
      setSubmittingReplyId(null);
    }
  };

  const handleDeleteMessage = async (messageId: string) => {
    if (!window.confirm('Voulez-vous vraiment supprimer ce message ?')) return;

    setError('');
    setSuccess('');
    try {
      const { error: deleteError } = await supabase
        .from('support_messages')
        .delete()
        .eq('id', messageId);

      if (deleteError) throw deleteError;

      setSuccess('Message supprimé.');
      setMessages(prev => prev.filter(m => m.id !== messageId));
    } catch (err: any) {
      setError(err.message || 'Erreur lors de la suppression du message.');
    }
  };

  const filteredMessages = messages.filter(m => {
    const matchesSearch =
      m.content.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (m.user_name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (m.user_phone || '').includes(searchTerm) ||
      (m.admin_reply || '').toLowerCase().includes(searchTerm.toLowerCase());

    const matchesType = typeFilter === 'all' || m.message_type === typeFilter;
    
    const matchesStatus =
      statusFilter === 'all' ||
      (statusFilter === 'pending' && !m.admin_reply) ||
      (statusFilter === 'replied' && !!m.admin_reply);

    return matchesSearch && matchesType && matchesStatus;
  });

  return (
    <div className="max-w-6xl mx-auto space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-12">
      {/* Header and Controls */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4">
          <div>
            <h2 className="text-xl font-heading flex items-center gap-2 text-slate-900">
              <MessageSquare className="text-primary" size={24} /> Suggestions & Questions
            </h2>
            <p className="text-sm text-slate-500">
              Répondez aux questions et lisez les suggestions d'amélioration des candidats de l'application mobile.
            </p>
          </div>
          
          <button
            onClick={fetchMessages}
            disabled={isLoading}
            className="flex items-center gap-2 px-4 py-2 border border-slate-200 rounded-xl text-sm font-bold bg-slate-50 hover:bg-slate-100 transition-colors disabled:opacity-50"
          >
            <RefreshCw size={16} className={isLoading ? 'animate-spin' : ''} />
            Rafraîchir
          </button>
        </div>

        {/* Filter Bar */}
        <div className="grid grid-cols-1 md:grid-cols-12 gap-4 mt-6 pt-6 border-t border-slate-100">
          {/* Search Input */}
          <div className="md:col-span-5 relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Rechercher par nom, téléphone, message..."
              className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all"
            />
          </div>

          {/* Type Filter */}
          <div className="md:col-span-3 flex items-center gap-2">
            <Filter size={14} className="text-slate-400 shrink-0" />
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value as any)}
              className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
            >
              <option value="all">Tous les types</option>
              <option value="question">Questions uniquement</option>
              <option value="suggestion">Suggestions uniquement</option>
            </select>
          </div>

          {/* Status Filter */}
          <div className="md:col-span-4 flex items-center gap-2">
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value as any)}
              className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
            >
              <option value="all">Tous les statuts</option>
              <option value="pending">En attente de réponse</option>
              <option value="replied">Déjà répondu</option>
            </select>
          </div>
        </div>
      </div>

      {/* Error & Success Messages */}
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

      {/* Messages List */}
      {isLoading ? (
        <div className="flex flex-col items-center justify-center py-24 text-slate-400 gap-3">
          <RefreshCw className="animate-spin" size={36} />
          <p className="text-sm">Chargement des questions et suggestions...</p>
        </div>
      ) : filteredMessages.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-16 text-center shadow-sm">
          <MessageSquare size={44} className="mx-auto text-slate-200 mb-3" />
          <p className="text-slate-500 font-semibold">Aucun message trouvé.</p>
          <p className="text-xs text-slate-400 mt-1">Essayez de modifier vos filtres de recherche.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredMessages.map((msg) => (
            <div
              key={msg.id}
              className={`bg-white rounded-2xl border p-6 shadow-sm transition-all hover:border-slate-300 ${
                !msg.admin_reply ? 'border-l-4 border-l-primary' : 'border-slate-200'
              }`}
            >
              {/* Message Header */}
              <div className="flex flex-wrap justify-between items-start gap-2 mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center font-bold text-slate-600 text-sm">
                    {msg.user_name?.charAt(0)}
                  </div>
                  <div>
                    <h4 className="font-bold text-slate-900 text-sm leading-tight">{msg.user_name}</h4>
                    <p className="text-[11px] text-slate-400 mt-0.5">{msg.user_phone}</p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  {/* Message Type Badge */}
                  <span
                    className={`px-2.5 py-0.5 rounded-lg text-[9px] font-black uppercase tracking-wider ${
                      msg.message_type === 'question'
                        ? 'bg-blue-50 text-blue-600 border border-blue-100'
                        : 'bg-green-50 text-green-600 border border-green-100'
                    }`}
                  >
                    {msg.message_type === 'question' ? 'Question' : 'Suggestion'}
                  </span>

                  {/* Reply Status Badge */}
                  <span
                    className={`px-2.5 py-0.5 rounded-lg text-[9px] font-black uppercase tracking-wider ${
                      msg.admin_reply ? 'bg-slate-100 text-slate-600' : 'bg-orange-50 text-primary border border-orange-100'
                    }`}
                  >
                    {msg.admin_reply ? 'Répondu' : 'En attente'}
                  </span>

                  <button
                    onClick={() => handleDeleteMessage(msg.id)}
                    className="p-1.5 text-slate-400 hover:text-red-500 rounded-lg hover:bg-slate-50 transition-colors ml-2"
                    title="Supprimer"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>

              {/* Message Content */}
              <div className="text-slate-800 text-sm bg-slate-50 rounded-xl p-4 border border-slate-100 whitespace-pre-wrap leading-relaxed">
                {msg.content}
                <div className="text-right text-[10px] text-slate-400 mt-2 font-medium">
                  Reçu le {new Date(msg.created_at).toLocaleDateString('fr-FR', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                  })}
                </div>
              </div>

              {/* Reply Section */}
              <div className="mt-4 pt-4 border-t border-slate-100">
                {msg.admin_reply ? (
                  <div className="space-y-2">
                    <div className="flex items-center gap-2 text-xs font-bold text-slate-500">
                      <CornerDownRight size={14} className="text-slate-400" />
                      <span>Votre réponse :</span>
                    </div>
                    <div className="bg-orange-50/30 border border-orange-100/50 rounded-xl p-4 ml-6 whitespace-pre-wrap text-sm text-slate-800 relative">
                      {msg.admin_reply}
                      <div className="text-right text-[10px] text-slate-400 mt-2 font-medium">
                        Répondu le {new Date(msg.replied_at!).toLocaleDateString('fr-FR', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </div>
                    </div>
                    
                    {/* Allow editing reply */}
                    <details className="ml-6 mt-2">
                      <summary className="text-[11px] text-slate-400 hover:text-primary cursor-pointer select-none font-semibold focus:outline-none">
                        Modifier la réponse
                      </summary>
                      <div className="mt-2 space-y-2">
                        <textarea
                          value={replyTexts[msg.id] ?? msg.admin_reply}
                          onChange={(e) => setReplyTexts(prev => ({ ...prev, [msg.id]: e.target.value }))}
                          placeholder="Modifier votre réponse..."
                          rows={3}
                          className="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                        <button
                          onClick={() => handleSendReply(msg.id)}
                          disabled={submittingReplyId === msg.id}
                          className="flex items-center gap-1.5 px-3 py-1.5 bg-primary text-white rounded-lg text-xs font-bold hover:bg-orange-650 transition-colors"
                        >
                          <Send size={12} /> Enregistrer les modifications
                        </button>
                      </div>
                    </details>
                  </div>
                ) : (
                  <div className="space-y-3">
                    <div className="flex items-center gap-2 text-xs font-bold text-slate-700">
                      <CornerDownRight size={14} className="text-slate-400" />
                      <span>Rédiger une réponse :</span>
                    </div>
                    <div className="flex gap-2 items-end ml-6">
                      <textarea
                        value={replyTexts[msg.id] || ''}
                        onChange={(e) => setReplyTexts(prev => ({ ...prev, [msg.id]: e.target.value }))}
                        placeholder="Écrivez votre réponse ici pour que l'utilisateur la reçoive sur son mobile..."
                        rows={3}
                        className="w-full flex-1 px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 resize-none"
                      />
                      <button
                        onClick={() => handleSendReply(msg.id)}
                        disabled={submittingReplyId === msg.id || !replyTexts[msg.id]?.trim()}
                        className="bg-primary text-white p-3 rounded-xl hover:shadow-lg hover:shadow-primary/20 active:scale-95 transition-all disabled:opacity-50 disabled:active:scale-100 flex items-center justify-center"
                        title="Envoyer la réponse"
                      >
                        {submittingReplyId === msg.id ? (
                          <RefreshCw className="animate-spin" size={18} />
                        ) : (
                          <Send size={18} />
                        )}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default SupportTab;
