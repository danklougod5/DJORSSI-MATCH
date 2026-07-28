import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/cache/local_cache.dart';
import '../../../core/utils/error_translator.dart';

class ChatsListScreen extends StatefulWidget {
  final bool embedInNavBar;

  const ChatsListScreen({
    super.key,
    this.embedInNavBar = false,
  });

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _chats = [];
  String _searchQuery = '';
  RealtimeChannel? _chatChannel;
  bool _isMeRecruiterRole = false;

  @override
  void initState() {
    super.initState();
    _loadChatsFromCache();
    _loadChats();
    _subscribeToChatUpdates();
  }

  @override
  void dispose() {
    if (_chatChannel != null) {
      _supabase.removeChannel(_chatChannel!);
    }
    super.dispose();
  }

  Future<void> _loadChatsFromCache() async {
    try {
      final cachedChats = await LocalCache.load(LocalCache.chatsKey);
      if (cachedChats != null && cachedChats is List && mounted && _chats.isEmpty) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(cachedChats);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error reading chats cache: $e');
    }
  }

  void _subscribeToChatUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Listen to chat_messages table changes in real-time to refresh the list preview
    _chatChannel = _supabase
        .channel('public:chat_messages_list_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            if (mounted) {
              _loadChats(silent: true);
            }
          },
        )
        .subscribe();
  }

  Future<T> _retry<T>(Future<T> Function() fn, {int maxAttempts = 2}) async {
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        return await fn();
      } catch (e) {
        if (attempt >= maxAttempts) rethrow;
        final msg = e.toString().toLowerCase();
        // Retry only on network / 522 / timeout errors
        if (msg.contains('522') || msg.contains('timeout') || msg.contains('socketexception') || msg.contains('clientexception')) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _loadChats({bool silent = false}) async {
    if (!silent && _chats.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // 0. Charger le rôle recruteur de mon profil
      try {
        final myProfile = await _retry(() => _supabase
            .from('profiles')
            .select('is_recruiter')
            .eq('id', currentUser.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 8)));
        if (myProfile != null && mounted) {
          _isMeRecruiterRole = myProfile['is_recruiter'] == true;
        }
      } catch (e) {
        debugPrint('Error checking my recruiter role: $e');
      }

      // 1. Fetch all chats the user is involved in
      List rawChatList;
      try {
        rawChatList = await _retry(() => _supabase
            .from('recruiter_candidate_chats')
            .select('id, recruiter_id, candidate_id, deleted_by_recruiter, deleted_by_candidate')
            .or('recruiter_id.eq.${currentUser.id},candidate_id.eq.${currentUser.id}')
            .timeout(const Duration(seconds: 12))) as List;
      } catch (e) {
        debugPrint('Soft delete columns not found in schema yet, falling back: $e');
        rawChatList = await _retry(() => _supabase
            .from('recruiter_candidate_chats')
            .select('id, recruiter_id, candidate_id')
            .or('recruiter_id.eq.${currentUser.id},candidate_id.eq.${currentUser.id}')
            .timeout(const Duration(seconds: 12))) as List;
      }

      final chatList = rawChatList.where((chat) {
        final bool isMeRecruiter = chat['recruiter_id'] == currentUser.id;
        if (isMeRecruiter) {
          return chat['deleted_by_recruiter'] != true;
        } else {
          return chat['deleted_by_candidate'] != true;
        }
      }).toList();

      if (chatList.isEmpty) {
        await LocalCache.save(LocalCache.chatsKey, []);
        if (mounted) {
          setState(() {
            _chats = [];
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      // 2. Extract all distinct partner IDs
      final otherUserIds = <String>{};
      for (var chat in chatList) {
        final recruiterId = chat['recruiter_id'] as String;
        final candidateId = chat['candidate_id'] as String;
        final otherUserId = (recruiterId == currentUser.id) ? candidateId : recruiterId;
        otherUserIds.add(otherUserId);
      }

      // 3. Batch query profile info for all partner IDs in ONE query
      final Map<String, Map<String, dynamic>> profilesMap = {};
      if (otherUserIds.isNotEmpty) {
        try {
          final profilesList = await _retry(() => _supabase
              .from('profiles')
              .select('id, full_name, company_name, is_recruiter')
              .inFilter('id', otherUserIds.toList())
              .timeout(const Duration(seconds: 12))) as List;
          for (var p in profilesList) {
            profilesMap[p['id'] as String] = Map<String, dynamic>.from(p);
          }
        } catch (e) {
          debugPrint('Error batch loading profiles: $e');
        }
      }

      // 4. Fetch details for each chat in parallel
      final futures = chatList.map((chat) async {
        final chatId = chat['id'];
        final recruiterId = chat['recruiter_id'] as String;
        final candidateId = chat['candidate_id'] as String;
        final bool isMeRecruiter = recruiterId == currentUser.id;
        final otherUserId = isMeRecruiter ? candidateId : recruiterId;

        final otherUser = profilesMap[otherUserId];
        if (otherUser == null) return null;

        Map<String, dynamic>? lastMsgResponse;
        int unreadCount = 0;

        try {
          final results = await Future.wait([
            _supabase
                .from('chat_messages')
                .select('message, created_at, sender_id, is_read')
                .eq('chat_id', chatId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle()
                .timeout(const Duration(seconds: 8)),
            _supabase
                .from('chat_messages')
                .select('id')
                .eq('chat_id', chatId)
                .neq('sender_id', currentUser.id)
                .eq('is_read', false)
                .timeout(const Duration(seconds: 8)),
          ]);

          lastMsgResponse = results[0] as Map<String, dynamic>?;
          final unreadList = results[1] as List?;
          unreadCount = unreadList?.length ?? 0;
        } catch (e) {
          debugPrint('Error loading chat details for $chatId: $e');
        }

        return {
          'id': chatId,
          'other_user_id': otherUser['id'],
          'other_user_name': otherUser['full_name'] ?? 'Utilisateur',
          'other_user_company': otherUser['company_name'],
          'is_recruiter': otherUser['is_recruiter'] == true,
          'last_message': lastMsgResponse?['message'] ?? 'Aucun message',
          'last_message_time': lastMsgResponse?['created_at'],
          'unread_count': unreadCount,
        };
      });

      final List<Map<String, dynamic>> loadedChats = [];
      final results = await Future.wait(futures);
      for (var chat in results) {
        if (chat != null) {
          loadedChats.add(chat);
        }
      }

      // Sort chats by last message time
      loadedChats.sort((a, b) {
        final timeA = a['last_message_time'] != null
            ? DateTime.parse(a['last_message_time'])
            : DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b['last_message_time'] != null
            ? DateTime.parse(b['last_message_time'])
            : DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA); // Descending (newest first)
      });

      // Save to cache
      await LocalCache.save(LocalCache.chatsKey, loadedChats);

      if (mounted) {
        setState(() {
          _chats = loadedChats;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_chats.isEmpty) {
            _errorMessage = ErrorTranslator.translate(e);
          }
        });
      }
    }
  }

  Future<void> _deleteChat(String chatId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Supprimer la discussion'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette discussion ? Elle n\'apparaîtra plus dans votre liste de conversations. L\'administrateur conserve l\'accès.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final updateData = _isMeRecruiterRole
          ? {'deleted_by_recruiter': true}
          : {'deleted_by_candidate': true};

      await _supabase
          .from('recruiter_candidate_chats')
          .update(updateData)
          .eq('id', chatId);

      setState(() {
        _chats.removeWhere((c) => c['id'] == chatId);
      });
      await LocalCache.save(LocalCache.chatsKey, _chats);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discussion supprimée.')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      if (mounted) {
        final errStr = e.toString();
        final msg = (errStr.contains('deleted_by') || errStr.contains('42703') || errStr.contains('PGRST204'))
            ? 'Veuillez exécuter la migration SQL dans l\'éditeur Supabase pour activer la suppression.'
            : 'Erreur lors de la suppression: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dateTime = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inDays == 0 && dateTime.day == now.day) {
        return DateFormat('HH:mm').format(dateTime);
      } else if (diff.inDays == 1 || (diff.inDays == 0 && dateTime.day != now.day)) {
        return 'Hier';
      } else if (diff.inDays < 7) {
        // Return day of the week
        final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
        return days[dateTime.weekday - 1];
      } else {
        return DateFormat('dd/MM').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  Color _getAvatarColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    final List<Color> colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Orange/Amber
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _chats.where((chat) {
      final name = chat['other_user_name'].toString().toLowerCase();
      final company = (chat['other_user_company'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || company.contains(query);
    }).toList();

    final Color themeColor = _isMeRecruiterRole ? const Color(0xFF1E3A8A) : const Color(0xFFF97316);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Messagerie',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: widget.embedInNavBar,
        leading: widget.embedInNavBar
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher une discussion...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide(color: themeColor, width: 1.5),
                ),
              ),
            ),
          ),

          // Chats List
          Expanded(
            child: _isLoading && _chats.isEmpty
                ? Center(child: CircularProgressIndicator(color: themeColor))
                : _errorMessage != null && _chats.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _loadChats(silent: true),
                        color: themeColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 60.h),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  color: const Color(0xFFEF4444),
                                  size: 64.r,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Impossible de charger vos discussions',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                ElevatedButton.icon(
                                  onPressed: () => _loadChats(),
                                  icon: const Icon(Icons.refresh, color: Colors.white),
                                  label: const Text('Réessayer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                : filteredChats.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _loadChats(silent: true),
                        color: themeColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 80.h),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: const Color(0xFF94A3B8),
                                  size: 64.r,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Aucune discussion en cours.'
                                      : 'Aucun résultat trouvé.',
                                  style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B)),
                                ),
                                if (_searchQuery.isEmpty) ...[
                                  SizedBox(height: 8.h),
                                  Text(
                                    _isMeRecruiterRole
                                        ? 'Swipez à droite sur des candidats intéressants pour chater.'
                                        : 'Attendez qu\'un recruteur initie une discussion avec vous !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadChats(silent: true),
                        color: themeColor,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          itemCount: filteredChats.length,
                          separatorBuilder: (context, index) => SizedBox(height: 8.h),
                          itemBuilder: (context, index) {
                            final chat = filteredChats[index];
                            final lastMsgTime = _formatTime(chat['last_message_time']);
                            final initials = chat['other_user_name']
                                .toString()
                                .split(' ')
                                .map((s) => s.isNotEmpty ? s[0] : '')
                                .take(2)
                                .join()
                                .toUpperCase();

                            final hasUnread = chat['unread_count'] > 0;

                            return InkWell(
                              onTap: () async {
                                await context.push('/chat/${chat['id']}', extra: {
                                  'otherUserName': chat['other_user_name'],
                                  'otherUserCompany': chat['other_user_company'],
                                  'isRecruiter': _isMeRecruiterRole,
                                });
                                // Refresh when returning to update read status
                                _loadChats(silent: true);
                              },
                              onLongPress: () => _deleteChat(chat['id']),
                              borderRadius: BorderRadius.circular(20.r),
                              child: Container(
                                padding: EdgeInsets.all(14.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: hasUnread ? themeColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
                                    width: hasUnread ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 26.r,
                                      backgroundColor: _getAvatarColor(chat['other_user_name']),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 14.w),

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  chat['other_user_name'],
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 15.sp,
                                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                lastMsgTime,
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: hasUnread ? themeColor : const Color(0xFF94A3B8),
                                                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (chat['other_user_company'] != null) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              chat['other_user_company'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: themeColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          SizedBox(height: 4.h),
                                          Text(
                                            chat['last_message'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              color: hasUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Unread Badge
                                    if (hasUnread) ...[
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: themeColor,
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Text(
                                          chat['unread_count'].toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],

                                    // More options (Delete chat)
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(Icons.more_vert, color: const Color(0xFF94A3B8), size: 20.r),
                                      onSelected: (val) {
                                        if (val == 'delete') {
                                          _deleteChat(chat['id']);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                              SizedBox(width: 8),
                                              Text('Supprimer la discussion', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
