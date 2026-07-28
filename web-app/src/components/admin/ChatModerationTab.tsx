import React, { useState, useEffect, useMemo } from 'react';
import { 
  Search, 
  MessageSquare, 
  ShieldAlert, 
  UserX, 
  RefreshCw, 
  AlertCircle, 
  Volume2, 
  Trash2, 
  Building2, 
  User, 
  UserCheck, 
  MessageCircle, 
  Clock,
  Eye,
  EyeOff,
  ShieldCheck
} from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface ChatSession {
  id: string;
  created_at: string;
  recruiter_id: string;
  candidate_id: string;
  recruiter_name: string;
  recruiter_company?: string;
  recruiter_blocked: boolean;
  candidate_name: string;
  candidate_blocked: boolean;
  last_message: string;
  last_message_time?: string;
  message_count: number;
  deleted_by_recruiter?: boolean;
  deleted_by_candidate?: boolean;
}

interface ChatMessage {
  id: string;
  chat_id: string;
  sender_id: string;
  sender_name: string;
  message: string;
  message_type?: string;
  media_url?: string;
  created_at: string;
  is_deleted?: boolean;
  reply_to_text?: string;
  reply_to_sender?: string;
}

interface ChatModerationTabProps {
  onToggleBlockUser: (userId: string, currentBlocked: boolean) => Promise<void>;
}

const ChatModerationTab: React.FC<ChatModerationTabProps> = ({ onToggleBlockUser }) => {
  const [chats, setChats] = useState<ChatSession[]>([]);
  const [selectedChat, setSelectedChat] = useState<ChatSession | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loadingChats, setLoadingChats] = useState(true);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterType, setFilterType] = useState<'all' | 'recruiter_blocked' | 'candidate_blocked'>('all');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [revealedMessages, setRevealedMessages] = useState<Record<string, boolean>>({});

  const toggleRevealDeleted = (msgId: string) => {
    setRevealedMessages(prev => ({ ...prev, [msgId]: !prev[msgId] }));
  };

  useEffect(() => {
    fetchChats();
  }, []);

  useEffect(() => {
    if (selectedChat) {
      fetchMessages(selectedChat.id);
    } else {
      setMessages([]);
    }
  }, [selectedChat?.id]);

  const fetchChats = async () => {
    setLoadingChats(true);
    try {
      // 1. Fetch all recruiter_candidate_chats
      const { data: chatList, error: chatError } = await supabase
        .from('recruiter_candidate_chats')
        .select('*')
        .order('created_at', { ascending: false });

      if (chatError) throw chatError;

      if (!chatList || chatList.length === 0) {
        setChats([]);
        setLoadingChats(false);
        return;
      }

      // Collect user IDs to fetch profiles in bulk
      const userIds = new Set<string>();
      chatList.forEach((c: any) => {
        if (c.recruiter_id) userIds.add(c.recruiter_id);
        if (c.candidate_id) userIds.add(c.candidate_id);
      });

      const { data: profiles, error: profileError } = await supabase
        .from('profiles')
        .select('id, full_name, company_name, is_blocked')
        .in('id', Array.from(userIds));

      if (profileError) throw profileError;

      const profileMap = new Map<string, any>();
      (profiles || []).forEach((p: any) => profileMap.set(p.id, p));

      // Build chat sessions with profile & last message info
      const formattedChats: ChatSession[] = [];

      for (const chat of chatList) {
        const recruiter = profileMap.get(chat.recruiter_id);
        const candidate = profileMap.get(chat.candidate_id);

        // Fetch last message for preview
        const { data: lastMsgData } = await supabase
          .from('chat_messages')
          .select('message, created_at')
          .eq('chat_id', chat.id)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        // Fetch message count
        const { count } = await supabase
          .from('chat_messages')
          .select('id', { count: 'exact', head: true })
          .eq('chat_id', chat.id);

        formattedChats.push({
          id: chat.id,
          created_at: chat.created_at,
          recruiter_id: chat.recruiter_id,
          candidate_id: chat.candidate_id,
          recruiter_name: recruiter?.full_name || 'Recruteur Inconnu',
          recruiter_company: recruiter?.company_name,
          recruiter_blocked: recruiter?.is_blocked === true,
          candidate_name: candidate?.full_name || 'Candidat Inconnu',
          candidate_blocked: candidate?.is_blocked === true,
          last_message: lastMsgData?.message || 'Aucun message',
          last_message_time: lastMsgData?.created_at || chat.created_at,
          message_count: count || 0,
          deleted_by_recruiter: chat.deleted_by_recruiter === true,
          deleted_by_candidate: chat.deleted_by_candidate === true,
        });
      }

      setChats(formattedChats);
      if (formattedChats.length > 0 && !selectedChat) {
        setSelectedChat(formattedChats[0]);
      }
    } catch (err) {
      console.error('Error fetching chats:', err);
    } finally {
      setLoadingChats(false);
    }
  };

  const fetchMessages = async (chatId: string) => {
    setLoadingMessages(true);
    try {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', { ascending: true });

      if (error) throw error;

      // Find user names
      const recruiterName = selectedChat?.recruiter_name || 'Recruteur';
      const candidateName = selectedChat?.candidate_name || 'Candidat';

      const formattedMsgs: ChatMessage[] = (data || []).map((m: any) => {
        const isRecruiter = m.sender_id === selectedChat?.recruiter_id;
        return {
          id: m.id,
          chat_id: m.chat_id,
          sender_id: m.sender_id,
          sender_name: isRecruiter ? recruiterName : candidateName,
          message: m.message,
          message_type: m.message_type,
          media_url: m.media_url,
          created_at: m.created_at,
          is_deleted: m.is_deleted,
          reply_to_text: m.reply_to_text,
          reply_to_sender: m.reply_to_sender,
        };
      });

      setMessages(formattedMsgs);
    } catch (err) {
      console.error('Error fetching messages:', err);
    } finally {
      setLoadingMessages(false);
    }
  };

  const handleToggleBlock = async (userId: string, currentBlocked: boolean) => {
    setActionLoading(userId);
    try {
      await onToggleBlockUser(userId, currentBlocked);
      // Refresh local chats list
      await fetchChats();
      if (selectedChat) {
        setSelectedChat((prev) => {
          if (!prev) return null;
          if (prev.recruiter_id === userId) {
            return { ...prev, recruiter_blocked: !currentBlocked };
          }
          if (prev.candidate_id === userId) {
            return { ...prev, candidate_blocked: !currentBlocked };
          }
          return prev;
        });
      }
    } catch (err) {
      console.error('Error blocking user:', err);
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeleteMessage = async (messageId: string) => {
    if (!window.confirm('Voulez-vous vraiment supprimer ce message de la discussion ?')) return;

    try {
      const { error } = await supabase
        .from('chat_messages')
        .update({ is_deleted: true, message: 'Ce message a été supprimé par l\'administrateur' })
        .eq('id', messageId);

      if (error) throw error;

      setMessages((prev) =>
        prev.map((m) =>
          m.id === messageId
            ? { ...m, is_deleted: true, message: 'Ce message a été supprimé par l\'administrateur' }
            : m
        )
      );
    } catch (err: any) {
      alert('Erreur lors de la suppression du message : ' + (err.message || err));
    }
  };

  const handleRestoreChat = async (chatId: string) => {
    if (!window.confirm('Voulez-vous restaurer et réafficher cette discussion pour le recruteur et le candidat ?')) return;

    setActionLoading(chatId);
    try {
      const { error } = await supabase
        .from('recruiter_candidate_chats')
        .update({ deleted_by_recruiter: false, deleted_by_candidate: false })
        .eq('id', chatId);

      if (error) throw error;

      setChats((prev) =>
        prev.map((c) =>
          c.id === chatId
            ? { ...c, deleted_by_recruiter: false, deleted_by_candidate: false }
            : c
        )
      );

      if (selectedChat?.id === chatId) {
        setSelectedChat((prev) =>
          prev ? { ...prev, deleted_by_recruiter: false, deleted_by_candidate: false } : null
        );
      }
    } catch (err: any) {
      alert('Erreur lors de la restauration de la discussion : ' + (err.message || err));
    } finally {
      setActionLoading(null);
    }
  };

  // Metrics
  const totalChats = chats.length;
  const totalMessagesCount = useMemo(() => chats.reduce((acc, c) => acc + c.message_count, 0), [chats]);
  const recruiterBlockedCount = useMemo(() => chats.filter(c => c.recruiter_blocked).length, [chats]);
  const candidateBlockedCount = useMemo(() => chats.filter(c => c.candidate_blocked).length, [chats]);

  const filteredChats = useMemo(() => {
    return chats.filter((c) => {
      // 1. Status Filter
      if (filterType === 'recruiter_blocked' && !c.recruiter_blocked) return false;
      if (filterType === 'candidate_blocked' && !c.candidate_blocked) return false;

      // 2. Search Term
      const q = searchTerm.toLowerCase().trim();
      if (!q) return true;

      return (
        c.recruiter_name.toLowerCase().includes(q) ||
        c.candidate_name.toLowerCase().includes(q) ||
        (c.recruiter_company && c.recruiter_company.toLowerCase().includes(q)) ||
        c.last_message.toLowerCase().includes(q)
      );
    });
  }, [chats, filterType, searchTerm]);

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
      {/* Top Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-wider">Conversations</p>
            <h4 className="text-2xl font-black text-slate-900 mt-1">{totalChats}</h4>
          </div>
          <MessageSquare className="text-primary/30" size={28} />
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-wider">Messages Échangés</p>
            <h4 className="text-2xl font-black text-blue-600 mt-1">{totalMessagesCount}</h4>
          </div>
          <MessageCircle className="text-blue-300" size={28} />
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div>
            <p className="text-[10px] font-black text-purple-600 uppercase tracking-wider">Recruteurs Bloqués</p>
            <h4 className="text-2xl font-black text-purple-900 mt-1">{recruiterBlockedCount}</h4>
          </div>
          <Building2 className="text-purple-300" size={28} />
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div>
            <p className="text-[10px] font-black text-orange-600 uppercase tracking-wider">Candidats Bloqués</p>
            <h4 className="text-2xl font-black text-orange-900 mt-1">{candidateBlockedCount}</h4>
          </div>
          <UserX className="text-orange-300" size={28} />
        </div>
      </div>

      {/* Top Info Banner */}
      <div className="bg-white p-6 rounded-3xl border border-slate-200 shadow-sm flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <div className="flex items-center gap-2">
            <ShieldAlert className="text-primary" size={24} />
            <h3 className="text-lg font-black text-slate-900 uppercase tracking-tight">Supervision & Consultation des Messages</h3>
          </div>
          <p className="text-xs text-slate-500 font-medium mt-1">
            Consultez en temps réel l'ensemble des échanges entre recruteurs et candidats, prévisualisez les fichiers/médias et modérez les messages.
          </p>
        </div>

        <button
          onClick={fetchChats}
          disabled={loadingChats}
          className="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-700 hover:bg-slate-200 rounded-xl text-xs font-bold transition-all shadow-sm"
        >
          <RefreshCw size={14} className={loadingChats ? 'animate-spin' : ''} />
          <span>Actualiser Discussions</span>
        </button>
      </div>

      {/* Main Split Interface */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 min-h-[600px]">
        {/* Left List of Discussions */}
        <div className="lg:col-span-4 bg-white rounded-3xl border border-slate-200 shadow-sm flex flex-col overflow-hidden">
          {/* Filter Sub-Tabs */}
          <div className="p-3 border-b border-slate-100 bg-slate-50/70 flex flex-wrap gap-1.5">
            <button
              onClick={() => setFilterType('all')}
              className={`px-3 py-1.5 rounded-lg text-[11px] font-bold transition-all ${
                filterType === 'all'
                  ? 'bg-slate-900 text-white shadow-sm'
                  : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200'
              }`}
            >
              Toutes ({totalChats})
            </button>
            <button
              onClick={() => setFilterType('recruiter_blocked')}
              className={`px-3 py-1.5 rounded-lg text-[11px] font-bold transition-all ${
                filterType === 'recruiter_blocked'
                  ? 'bg-purple-700 text-white shadow-sm'
                  : 'bg-white text-purple-700 hover:bg-purple-50 border border-purple-200'
              }`}
            >
              Recruteur Bloqué ({recruiterBlockedCount})
            </button>
            <button
              onClick={() => setFilterType('candidate_blocked')}
              className={`px-3 py-1.5 rounded-lg text-[11px] font-bold transition-all ${
                filterType === 'candidate_blocked'
                  ? 'bg-orange-600 text-white shadow-sm'
                  : 'bg-white text-orange-700 hover:bg-orange-50 border border-orange-200'
              }`}
            >
              Candidat Bloqué ({candidateBlockedCount})
            </button>
          </div>

          {/* Search bar */}
          <div className="p-3.5 border-b border-slate-100 bg-white">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={15} />
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Rechercher nom, entreprise, extrait..."
                className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-900 focus:outline-none focus:border-primary"
              />
            </div>
          </div>

          {/* List items */}
          <div className="flex-1 overflow-y-auto divide-y divide-slate-100 max-h-[520px]">
            {loadingChats ? (
              <div className="p-12 text-center text-slate-400">
                <RefreshCw size={24} className="animate-spin mx-auto mb-2 text-primary" />
                <p className="text-xs font-medium">Chargement des conversations...</p>
              </div>
            ) : filteredChats.length === 0 ? (
              <div className="p-12 text-center text-slate-400">
                <MessageSquare size={32} className="mx-auto mb-2 opacity-30" />
                <p className="text-xs italic font-medium">Aucune conversation trouvée.</p>
              </div>
            ) : (
              filteredChats.map((chat) => {
                const isSelected = selectedChat?.id === chat.id;
                const hasBlockedUser = chat.recruiter_blocked || chat.candidate_blocked;

                return (
                  <button
                    key={chat.id}
                    onClick={() => setSelectedChat(chat)}
                    className={`w-full p-4 text-left transition-all flex flex-col gap-2 ${
                      isSelected
                        ? 'bg-primary/5 border-l-4 border-primary'
                        : 'hover:bg-slate-50 border-l-4 border-transparent'
                    }`}
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1 min-w-0 pr-2">
                        <div className="flex items-center gap-1.5 font-bold text-xs text-slate-900 truncate">
                          <span className="text-purple-900">{chat.recruiter_name}</span>
                          <span className="text-slate-300">↔</span>
                          <span className="text-orange-900">{chat.candidate_name}</span>
                        </div>
                        {chat.recruiter_company && (
                          <p className="text-[10px] text-slate-500 font-semibold truncate mt-0.5">
                            🏢 {chat.recruiter_company}
                          </p>
                        )}
                      </div>

                      <div className="flex flex-col items-end gap-1">
                        {hasBlockedUser && (
                          <span className="px-2 py-0.5 bg-red-100 text-red-700 rounded-full text-[9px] font-black uppercase tracking-wider">
                            Bloqué 🔴
                          </span>
                        )}
                        {(chat.deleted_by_recruiter || chat.deleted_by_candidate) && (
                          <span className="px-2 py-0.5 bg-amber-100 text-amber-800 rounded-full text-[9px] font-black uppercase tracking-wider">
                            {chat.deleted_by_recruiter && chat.deleted_by_candidate
                              ? 'Masquée (Tous) 👁️‍🗨️'
                              : chat.deleted_by_recruiter
                              ? 'Masquée (Recruteur) 👁️‍🗨️'
                              : 'Masquée (Candidat) 👁️‍🗨️'}
                          </span>
                        )}
                      </div>
                    </div>

                    <p className="text-xs text-slate-600 truncate italic">
                      "{chat.last_message}"
                    </p>

                    <div className="flex justify-between items-center text-[10px] text-slate-400 font-mono mt-1">
                      <span>{chat.message_count} message{chat.message_count > 1 ? 's' : ''}</span>
                      <span className="flex items-center gap-1">
                        <Clock size={10} />
                        {new Date(chat.last_message_time || chat.created_at).toLocaleDateString('fr-FR', {
                          day: 'numeric',
                          month: 'short',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </span>
                    </div>
                  </button>
                );
              })
            )}
          </div>
        </div>

        {/* Right Conversation Inspector */}
        <div className="lg:col-span-8 bg-white rounded-3xl border border-slate-200 shadow-sm flex flex-col overflow-hidden">
          {selectedChat ? (
            <>
              {/* Header with User Info Cards */}
              <div className="p-4 border-b border-slate-100 bg-slate-50/70 space-y-3">
                <div className="flex justify-between items-center flex-wrap gap-2">
                  <div>
                    <h4 className="font-black text-sm text-slate-900 flex items-center gap-2">
                      <MessageSquare size={16} className="text-primary" />
                      Fil de discussion en direct
                    </h4>
                    <p className="text-[10px] text-slate-400 font-mono mt-0.5">
                      ID: {selectedChat.id}
                    </p>
                  </div>

                  <div className="flex items-center gap-2">
                    {(selectedChat.deleted_by_recruiter || selectedChat.deleted_by_candidate) && (
                      <button
                        onClick={() => handleRestoreChat(selectedChat.id)}
                        disabled={actionLoading === selectedChat.id}
                        className="px-3 py-1.5 bg-amber-500 hover:bg-amber-600 text-white rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 shadow-sm"
                        title="Restaurer la discussion pour la faire réapparaître dans l'application mobile"
                      >
                        <RefreshCw size={12} className={actionLoading === selectedChat.id ? 'animate-spin' : ''} />
                        <span>Faire ressortir cette discussion</span>
                      </button>
                    )}
                    <span className="px-3 py-1 bg-white border border-slate-200 rounded-full text-xs font-bold text-slate-700">
                      {selectedChat.message_count} messages
                    </span>
                  </div>
                </div>

                {(selectedChat.deleted_by_recruiter || selectedChat.deleted_by_candidate) && (
                  <div className="p-3 bg-amber-50/90 border border-amber-200 rounded-2xl flex justify-between items-center text-xs text-amber-900 font-medium">
                    <div className="flex items-center gap-2">
                      <AlertCircle size={16} className="text-amber-600 shrink-0" />
                      <span>
                        Cette discussion a été masquée côté utilisateur par{' '}
                        <strong className="font-bold">
                          {selectedChat.deleted_by_recruiter && selectedChat.deleted_by_candidate
                            ? 'le recruteur et le candidat'
                            : selectedChat.deleted_by_recruiter
                            ? 'le recruteur'
                            : 'le candidat'}
                        </strong>. L'administrateur peut la faire ressortir ci-dessus à tout moment.
                      </span>
                    </div>
                  </div>
                )}

                {/* Recruiter & Candidate Profile Quick Action Badges */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                  {/* Recruiter Badge */}
                  <div className="p-3 bg-purple-50/80 border border-purple-200 rounded-2xl flex justify-between items-center">
                    <div>
                      <p className="text-[10px] font-black text-purple-700 uppercase tracking-widest flex items-center gap-1">
                        <Building2 size={12} /> RECRUTEUR
                      </p>
                      <p className="text-xs font-bold text-slate-900 mt-0.5">
                        {selectedChat.recruiter_name}
                      </p>
                      {selectedChat.recruiter_company && (
                        <p className="text-[10px] text-slate-500 font-semibold">{selectedChat.recruiter_company}</p>
                      )}
                    </div>
                    <button
                      onClick={() => handleToggleBlock(selectedChat.recruiter_id, selectedChat.recruiter_blocked)}
                      disabled={actionLoading === selectedChat.recruiter_id}
                      className={`px-2.5 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-wider transition-all flex items-center gap-1 ${
                        selectedChat.recruiter_blocked
                          ? 'bg-emerald-600 text-white hover:bg-emerald-700'
                          : 'bg-red-600 text-white hover:bg-red-700'
                      }`}
                    >
                      {selectedChat.recruiter_blocked ? (
                        <>
                          <UserCheck size={12} /> Débloquer
                        </>
                      ) : (
                        <>
                          <UserX size={12} /> Bloquer
                        </>
                      )}
                    </button>
                  </div>

                  {/* Candidate Badge */}
                  <div className="p-3 bg-orange-50/80 border border-orange-200 rounded-2xl flex justify-between items-center">
                    <div>
                      <p className="text-[10px] font-black text-orange-700 uppercase tracking-widest flex items-center gap-1">
                        <User size={12} /> CANDIDAT
                      </p>
                      <p className="text-xs font-bold text-slate-900 mt-0.5">
                        {selectedChat.candidate_name}
                      </p>
                    </div>
                    <button
                      onClick={() => handleToggleBlock(selectedChat.candidate_id, selectedChat.candidate_blocked)}
                      disabled={actionLoading === selectedChat.candidate_id}
                      className={`px-2.5 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-wider transition-all flex items-center gap-1 ${
                        selectedChat.candidate_blocked
                          ? 'bg-emerald-600 text-white hover:bg-emerald-700'
                          : 'bg-red-600 text-white hover:bg-red-700'
                      }`}
                    >
                      {selectedChat.candidate_blocked ? (
                        <>
                          <UserCheck size={12} /> Débloquer
                        </>
                      ) : (
                        <>
                          <UserX size={12} /> Bloquer
                        </>
                      )}
                    </button>
                  </div>
                </div>
              </div>

              {/* Messages Body */}
              <div className="flex-1 p-6 overflow-y-auto space-y-4 max-h-[500px] bg-slate-50/30">
                {loadingMessages ? (
                  <div className="p-12 text-center text-slate-400">
                    <RefreshCw size={24} className="animate-spin mx-auto mb-2 text-primary" />
                    <p className="text-xs font-medium">Chargement du fil de discussion...</p>
                  </div>
                ) : messages.length === 0 ? (
                  <div className="p-12 text-center text-slate-400 italic text-xs font-medium">
                    Aucun message dans cette conversation.
                  </div>
                ) : (
                  messages.map((msg) => {
                    const isRecruiter = msg.sender_id === selectedChat.recruiter_id;

                    return (
                      <div
                        key={msg.id}
                        className={`flex flex-col group ${
                          isRecruiter ? 'items-end' : 'items-start'
                        }`}
                      >
                        <div className="flex items-center gap-2 mb-1">
                          <span
                            className={`text-[10px] font-bold px-2 py-0.5 rounded-md ${
                              isRecruiter
                                ? 'bg-purple-100 text-purple-900 border border-purple-200'
                                : 'bg-orange-100 text-orange-900 border border-orange-200'
                            }`}
                          >
                            {msg.sender_name} ({isRecruiter ? 'Recruteur' : 'Candidat'})
                          </span>
                          <span className="text-[10px] text-slate-400 font-mono">
                            {new Date(msg.created_at).toLocaleTimeString([], {
                              hour: '2-digit',
                              minute: '2-digit',
                            })}
                          </span>

                          {!msg.is_deleted && (
                            <button
                              onClick={() => handleDeleteMessage(msg.id)}
                              className="opacity-0 group-hover:opacity-100 p-1 text-slate-400 hover:text-red-600 transition-all"
                              title="Supprimer ce message (Modération Admin)"
                            >
                              <Trash2 size={13} />
                            </button>
                          )}
                        </div>

                        <div
                          className={`max-w-[80%] p-4 rounded-2xl text-xs space-y-2 relative ${
                            msg.is_deleted
                              ? 'bg-amber-50 text-slate-900 border-2 border-amber-300 shadow-sm'
                              : isRecruiter
                              ? 'bg-purple-900 text-white shadow-sm'
                              : 'bg-white text-slate-900 border border-slate-200 shadow-sm'
                          }`}
                        >
                          {/* Reply preview if quoted */}
                          {msg.reply_to_text && !msg.is_deleted && (
                            <div className="p-2 rounded-xl bg-black/10 border-l-2 border-primary text-[11px] mb-2">
                              <p className="font-bold text-[10px] opacity-75">
                                {msg.reply_to_sender || 'Message'}
                              </p>
                              <p className="truncate">{msg.reply_to_text}</p>
                            </div>
                          )}

                          {/* Message Content */}
                          {msg.is_deleted ? (
                            <div className="space-y-2">
                              <div className="flex items-center justify-between gap-3 text-amber-800 font-bold border-b border-amber-200 pb-2">
                                <div className="flex items-center gap-1.5 text-xs">
                                  <AlertCircle size={15} className="text-amber-600 shrink-0" />
                                  <span>Message Supprimé par l'utilisateur</span>
                                </div>
                                <button
                                  onClick={() => toggleRevealDeleted(msg.id)}
                                  className="px-2.5 py-1 bg-amber-200/80 hover:bg-amber-300 text-amber-950 rounded-lg text-[10px] font-black uppercase tracking-wider transition-all flex items-center gap-1 shrink-0"
                                >
                                  {revealedMessages[msg.id] ? (
                                    <>
                                      <EyeOff size={12} /> Masquer
                                    </>
                                  ) : (
                                    <>
                                      <Eye size={12} /> Révéler l'original
                                    </>
                                  )}
                                </button>
                              </div>

                              {revealedMessages[msg.id] ? (
                                <div className="p-3 bg-white/90 rounded-xl border border-amber-300 space-y-2 text-slate-900 animate-in fade-in">
                                  <p className="text-[10px] font-black uppercase tracking-widest text-amber-700 flex items-center gap-1">
                                    <ShieldCheck size={12} /> Contenu Original Archivé (Preuve Juridique Admin)
                                  </p>
                                  {msg.message_type === 'image' && msg.media_url ? (
                                    <div className="space-y-2">
                                      <a
                                        href={msg.media_url}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="block rounded-lg overflow-hidden border border-amber-300 max-w-[240px]"
                                      >
                                        <img
                                          src={msg.media_url}
                                          alt="Archived Attachment"
                                          className="w-full h-auto object-cover max-h-48"
                                        />
                                      </a>
                                      {msg.message && <p className="font-medium text-slate-800">{msg.message}</p>}
                                    </div>
                                  ) : msg.message_type === 'audio' && msg.media_url ? (
                                    <div className="space-y-2">
                                      <div className="p-2 bg-slate-900 rounded-xl">
                                        <audio controls preload="metadata" src={msg.media_url} className="w-full h-8" />
                                      </div>
                                      <a
                                        href={msg.media_url}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="text-[10px] text-amber-800 font-bold underline block text-right"
                                      >
                                        Écouter le vocal archivé 🎧
                                      </a>
                                    </div>
                                  ) : (
                                    <p className="whitespace-pre-wrap font-medium text-slate-900 leading-relaxed">
                                      {msg.message}
                                    </p>
                                  )}
                                </div>
                              ) : (
                                <p className="text-[11px] text-amber-800 italic">
                                  Ce message a été supprimé du chat de l'utilisateur. Cliquez sur "Révéler l'original" pour consulter l'archive de protection juridique.
                                </p>
                              )}
                            </div>
                          ) : msg.message_type === 'image' && msg.media_url ? (
                            <div className="space-y-2">
                              <a
                                href={msg.media_url}
                                target="_blank"
                                rel="noreferrer"
                                className="block rounded-xl overflow-hidden border border-black/10 max-w-[260px]"
                              >
                                <img
                                  src={msg.media_url}
                                  alt="Attachment"
                                  className="w-full h-auto object-cover max-h-52"
                                />
                              </a>
                              <p className="text-[11px] opacity-90">{msg.message}</p>
                            </div>
                          ) : msg.message_type === 'audio' && msg.media_url ? (
                            <div className="space-y-2 p-1">
                              <div className="flex items-center gap-2 text-xs font-bold">
                                <Volume2 size={16} className={isRecruiter ? 'text-white' : 'text-primary'} />
                                <span>Message Vocal 🎤</span>
                              </div>
                              <div className="p-2 bg-slate-900 rounded-xl border border-slate-800 shadow-inner">
                                <audio
                                  controls
                                  preload="metadata"
                                  src={msg.media_url}
                                  className="w-full min-w-[240px] h-10 accent-primary rounded-lg"
                                />
                              </div>
                              <div className="flex justify-end">
                                <a
                                  href={msg.media_url}
                                  target="_blank"
                                  rel="noreferrer"
                                  className={`text-[10px] underline font-semibold flex items-center gap-1 ${
                                    isRecruiter ? 'text-white/80 hover:text-white' : 'text-primary hover:underline'
                                  }`}
                                >
                                  Ouvrir / Écouter l'audio 🎧
                                </a>
                              </div>
                            </div>
                          ) : (
                            <p className="whitespace-pre-wrap leading-relaxed">{msg.message}</p>
                          )}
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </>
          ) : (
            <div className="p-20 text-center text-slate-400">
              <MessageSquare size={48} className="mx-auto mb-3 opacity-20" />
              <p className="text-sm font-semibold">Sélectionnez une discussion à gauche pour consulter les messages.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default ChatModerationTab;
