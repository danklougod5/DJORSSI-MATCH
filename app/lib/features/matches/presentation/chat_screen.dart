import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserName;
  final String? otherUserCompany;
  final bool? isRecruiter;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.otherUserName,
    this.otherUserCompany,
    this.isRecruiter,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _realtimeChannel;
  late bool _isMeRecruiter;
  bool _isContextLoaded = false;
  String? _candidateId;
  String? _recruiterId;
  Map<String, dynamic>? _replyingToMessage;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  bool _isLoadingMedia = false;

  @override
  void initState() {
    super.initState();
    _isMeRecruiter = widget.isRecruiter ?? false;
    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadChatContext();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatContext() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // 1. Fetch the chat details to see who is who
      final chatDetails = await _supabase
          .from('recruiter_candidate_chats')
          .select('recruiter_id, candidate_id')
          .eq('id', widget.chatId)
          .single()
          .timeout(const Duration(seconds: 12));

      if (mounted) {
        setState(() {
          _isMeRecruiter = chatDetails['recruiter_id'] == currentUser.id;
          _recruiterId = chatDetails['recruiter_id'];
          _candidateId = chatDetails['candidate_id'];
          _isContextLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat context: $e');
      if (mounted) {
        setState(() {
          _isContextLoaded = true;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .select(
            'id, chat_id, sender_id, message, created_at, is_read, message_type, media_url, reply_to_message_id, reply_to_text, reply_to_sender, is_deleted',
          )
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 12));

      final List<Map<String, dynamic>> loadedMessages =
          List<Map<String, dynamic>>.from(response as List);

      if (mounted) {
        setState(() {
          _messages = loadedMessages;
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    // Listen to changes for this specific chat_id
    _realtimeChannel = _supabase
        .channel('public:chat_messages:${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newMsg = Map<String, dynamic>.from(payload.newRecord);
              if (mounted) {
                setState(() {
                  // Prevent duplicates if already inserted locally
                  if (!_messages.any((m) => m['id'] == newMsg['id'])) {
                    _messages.add(newMsg);
                  }
                });
                _scrollToBottom();
                if (newMsg['sender_id'] != _supabase.auth.currentUser?.id) {
                  _markMessagesAsRead();
                }
              }
            } else if (payload.eventType == PostgresChangeEvent.update) {
              final updatedMsg = Map<String, dynamic>.from(payload.newRecord);
              if (mounted) {
                setState(() {
                  final index = _messages.indexWhere(
                    (m) => m['id'] == updatedMsg['id'],
                  );
                  if (index != -1) {
                    _messages[index] = updatedMsg;
                  }
                });
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      // Optimistic update locally
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['is_deleted'] = true;
          }
        });
      }

      await _supabase
          .from('chat_messages')
          .update({'is_deleted': true})
          .eq('id', messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  Future<void> _confirmDeleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Supprimer la discussion'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette discussion ? Elle n\'apparaîtra plus dans votre liste de conversations. L\'administrateur conserve un accès à l\'historique.'
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

      final updateData = _isMeRecruiter
          ? {'deleted_by_recruiter': true}
          : {'deleted_by_candidate': true};

      await _supabase
          .from('recruiter_candidate_chats')
          .update(updateData)
          .eq('id', widget.chatId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discussion supprimée.')),
        );
        Navigator.of(context).pop();
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

  void _showMessageOptionsSheet(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDeleted = msg['is_deleted'] == true;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              if (!isDeleted)
                ListTile(
                  leading: Icon(
                    Icons.reply_rounded,
                    color: const Color(0xFF1E3A8A),
                    size: 24.r,
                  ),
                  title: Text(
                    'Répondre',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replyingToMessage = msg;
                    });
                  },
                ),
              if (isMe && !isDeleted)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444),
                    size: 24.r,
                  ),
                  title: Text(
                    'Supprimer le message',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteMessage(msg['id']);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markMessagesAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('chat_id', widget.chatId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<bool> _isCurrentUserBlocked() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final res = await _supabase
          .from('profiles')
          .select('is_blocked')
          .eq('id', userId)
          .maybeSingle();
      if (res != null && res['is_blocked'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Votre compte a été suspendu par l\'administration.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error checking blocked status: $e');
    }
    return false;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (await _isCurrentUserBlocked()) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _messageController.clear();

    final replyMsg = _replyingToMessage;
    final String? replyId = replyMsg?['id'];
    final String? replyText = replyMsg != null
        ? (replyMsg['message_type'] == 'image'
              ? '[Photo 📸]'
              : (replyMsg['message_type'] == 'audio'
                    ? '[Message Vocal 🎤]'
                    : (replyMsg['message'] ?? '')))
        : null;
    final String? replySender = replyMsg != null
        ? (replyMsg['sender_id'] == userId
              ? 'Vous'
              : (widget.otherUserName ?? 'Message'))
        : null;

    // Clear active reply state
    setState(() {
      _replyingToMessage = null;
    });

    // Optimistic insert local state to feel fast
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = {
      'id': tempId,
      'chat_id': widget.chatId,
      'sender_id': userId,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_read': false,
      'reply_to_message_id': replyId,
      'reply_to_text': replyText,
      'reply_to_sender': replySender,
    };

    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottom();

    try {
      final Map<String, dynamic> insertData = {
        'chat_id': widget.chatId,
        'sender_id': userId,
        'message': text,
      };
      if (replyId != null) {
        insertData['reply_to_message_id'] = replyId;
        insertData['reply_to_text'] = replyText;
        insertData['reply_to_sender'] = replySender;
      }

      final response = await _supabase
          .from('chat_messages')
          .insert(insertData)
          .select('id, created_at')
          .single();

      // Update optimistic message with real db values
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index]['id'] = response['id'];
            _messages[index]['created_at'] = response['created_at'];
          }
        });
      }

      // If the sender is the recruiter, send a push notification to the candidate
      if (_isMeRecruiter && _candidateId != null) {
        _sendPushNotification(text, userId);
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d\'envoyer le message. Veuillez réessayer.',
            ),
          ),
        );
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
        });
      }
    }
  }

  Future<void> _sendPushNotification(
    String text,
    String recruiterUserId,
  ) async {
    try {
      // 1. Fetch company name of the recruiter
      final recruiterProfile = await _supabase
          .from('profiles')
          .select('company_name')
          .eq('id', recruiterUserId)
          .single();
      final companyName = recruiterProfile['company_name'] ?? 'Un recruteur';

      // 2. Trigger Supabase Edge Function to notify the candidate
      await _supabase.functions.invoke(
        'send-broadcast-notification',
        body: {
          'title': 'Nouveau Match et Message ! 🎉💬',
          'message':
              "L'entreprise $companyName a matché avec vous et vous a écrit : \"$text\"",
          'target': _candidateId,
          'is_personal': false,
        },
      );
    } catch (e) {
      debugPrint('Error triggering match push notification: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDuration++;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
  }

  Future<void> _stopAndSendVoiceNote() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          setState(() {
            _isLoadingMedia = true;
          });

          final userId = _supabase.auth.currentUser?.id;
          if (userId == null) return;

          final replyMsg = _replyingToMessage;
          final String? replyId = replyMsg?['id'];
          final String? replyText = replyMsg != null
              ? (replyMsg['message_type'] == 'image'
                    ? '[Photo 📸]'
                    : (replyMsg['message_type'] == 'audio'
                          ? '[Message Vocal 🎤]'
                          : (replyMsg['message'] ?? '')))
              : null;
          final String? replySender = replyMsg != null
              ? (replyMsg['sender_id'] == userId
                    ? 'Vous'
                    : (widget.otherUserName ?? 'Message'))
              : null;

          setState(() {
            _replyingToMessage = null;
          });

          final fileBytes = await file.readAsBytes();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
          final storagePath = '${widget.chatId}/$fileName';

          // Upload to Supabase Storage
          await _supabase.storage
              .from('chat_attachments')
              .uploadBinary(storagePath, fileBytes);

          // Get Public URL
          final mediaUrl = _supabase.storage
              .from('chat_attachments')
              .getPublicUrl(storagePath);

          final Map<String, dynamic> insertData = {
            'chat_id': widget.chatId,
            'sender_id': userId,
            'message': '[Message Vocal 🎤]',
            'message_type': 'audio',
            'media_url': mediaUrl,
          };
          if (replyId != null) {
            insertData['reply_to_message_id'] = replyId;
            insertData['reply_to_text'] = replyText;
            insertData['reply_to_sender'] = replySender;
          }

          // Save message to database
          final response = await _supabase
              .from('chat_messages')
              .insert(insertData)
              .select('id, created_at')
              .single();

          // Add to local UI
          setState(() {
            _messages.add({
              'id': response['id'],
              'chat_id': widget.chatId,
              'sender_id': userId,
              'message': '[Message Vocal 🎤]',
              'message_type': 'audio',
              'media_url': mediaUrl,
              'created_at': response['created_at'],
              'is_read': false,
              'reply_to_message_id': replyId,
              'reply_to_text': replyText,
              'reply_to_sender': replySender,
            });
          });
          _scrollToBottom();

          // Send push notification to target
          if (_isMeRecruiter && _candidateId != null) {
            _sendPushNotification('vous a envoyé un message vocal 🎤', userId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
    } finally {
      setState(() {
        _isLoadingMedia = false;
      });
    }
  }

  Future<void> _sendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;

      setState(() {
        _isLoadingMedia = true;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final replyMsg = _replyingToMessage;
      final String? replyId = replyMsg?['id'];
      final String? replyText = replyMsg != null
          ? (replyMsg['message_type'] == 'image'
                ? '[Photo 📸]'
                : (replyMsg['message_type'] == 'audio'
                      ? '[Message Vocal 🎤]'
                      : (replyMsg['message'] ?? '')))
          : null;
      final String? replySender = replyMsg != null
          ? (replyMsg['sender_id'] == userId
                ? 'Vous'
                : (widget.otherUserName ?? 'Message'))
          : null;

      setState(() {
        _replyingToMessage = null;
      });

      final fileBytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = '${widget.chatId}/$fileName';

      // Upload to Storage
      await _supabase.storage
          .from('chat_attachments')
          .uploadBinary(storagePath, fileBytes);

      // Get Public URL
      final mediaUrl = _supabase.storage
          .from('chat_attachments')
          .getPublicUrl(storagePath);

      final Map<String, dynamic> insertData = {
        'chat_id': widget.chatId,
        'sender_id': userId,
        'message': '[Photo 📸]',
        'message_type': 'image',
        'media_url': mediaUrl,
      };
      if (replyId != null) {
        insertData['reply_to_message_id'] = replyId;
        insertData['reply_to_text'] = replyText;
        insertData['reply_to_sender'] = replySender;
      }

      // Save message to database
      final response = await _supabase
          .from('chat_messages')
          .insert(insertData)
          .select('id, created_at')
          .single();

      // Add to local UI
      setState(() {
        _messages.add({
          'id': response['id'],
          'chat_id': widget.chatId,
          'sender_id': userId,
          'message': '[Photo 📸]',
          'message_type': 'image',
          'media_url': mediaUrl,
          'created_at': response['created_at'],
          'is_read': false,
          'reply_to_message_id': replyId,
          'reply_to_text': replyText,
          'reply_to_sender': replySender,
        });
      });
      _scrollToBottom();

      // Send push notification to target
      if (_isMeRecruiter && _candidateId != null) {
        _sendPushNotification('vous a envoyé une photo 📸', userId);
      }
    } catch (e) {
      debugPrint('Error sending image: $e');
    } finally {
      setState(() {
        _isLoadingMedia = false;
      });
    }
  }

  Future<void> _sendPdfDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final fileBytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

      if (fileBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de lire le fichier PDF.')),
          );
        }
        return;
      }

      setState(() {
        _isLoadingMedia = true;
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final replyMsg = _replyingToMessage;
      final String? replyId = replyMsg?['id'];
      final String? replyText = replyMsg != null
          ? (replyMsg['message_type'] == 'pdf'
                ? '[Document PDF 📄]'
                : (replyMsg['message_type'] == 'image'
                      ? '[Photo 📸]'
                      : (replyMsg['message_type'] == 'audio'
                            ? '[Message Vocal 🎤]'
                            : (replyMsg['message'] ?? ''))))
          : null;
      final String? replySender = replyMsg != null
          ? (replyMsg['sender_id'] == userId
                ? 'Vous'
                : (widget.otherUserName ?? 'Message'))
          : null;

      setState(() {
        _replyingToMessage = null;
      });

      final safeExt = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'pdf';
      final storageFileName = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      final storagePath = '${widget.chatId}/$storageFileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('chat_attachments')
          .uploadBinary(storagePath, fileBytes);

      // Get Public URL
      final mediaUrl = _supabase.storage
          .from('chat_attachments')
          .getPublicUrl(storagePath);

      final Map<String, dynamic> insertData = {
        'chat_id': widget.chatId,
        'sender_id': userId,
        'message': fileName,
        'message_type': 'pdf',
        'media_url': mediaUrl,
      };
      if (replyId != null) {
        insertData['reply_to_message_id'] = replyId;
        insertData['reply_to_text'] = replyText;
        insertData['reply_to_sender'] = replySender;
      }

      // Save message to database
      final response = await _supabase
          .from('chat_messages')
          .insert(insertData)
          .select('id, created_at')
          .single();

      // Add to local UI
      setState(() {
        _messages.add({
          'id': response['id'],
          'chat_id': widget.chatId,
          'sender_id': userId,
          'message': fileName,
          'message_type': 'pdf',
          'media_url': mediaUrl,
          'created_at': response['created_at'],
          'is_read': false,
          'reply_to_message_id': replyId,
          'reply_to_text': replyText,
          'reply_to_sender': replySender,
        });
      });
      _scrollToBottom();

      // Send push notification to target
      if (_isMeRecruiter && _candidateId != null) {
        _sendPushNotification('vous a envoyé un document PDF 📄', userId);
      }
    } catch (e) {
      debugPrint('Error sending PDF document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du fichier PDF.')),
        );
      }
    } finally {
      setState(() {
        _isLoadingMedia = false;
      });
    }
  }

  String _formatTimerDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _formatMessageTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dateTime = DateTime.parse(timeStr).toLocal();
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  Color _getAvatarColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    final List<Color> colors = [
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    return colors[hash % colors.length];
  }

  void _showReportUserModal(
    BuildContext context, {
    required String? otherUserId,
    required String otherName,
  }) {
    String selectedReason = 'money_asked';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          margin: EdgeInsets.only(bottom: 20.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: Color(0xFFEF4444),
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Signaler $otherName',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Transmettre un signalement à la modération',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'Motif du signalement',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<String>(
                        value: selectedReason,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 12.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'money_asked',
                            child: Text(
                              '💰 Demande d\'argent (frais de dossier...)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'scam',
                            child: Text(
                              '🚨 Arnaque / Fausse offre de recrutement',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'suspicious_behavior',
                            child: Text(
                              '⚠️ Comportement suspect / Harcèlement',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('❓ Autre motif de signalement'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedReason = val);
                          }
                        },
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Détails explicatifs (facultatif)',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: detailsController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText:
                              'Décrivez précisément la raison de votre signalement...',
                          contentPadding: EdgeInsets.all(14.w),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.gavel_rounded,
                              color: const Color(0xFFDC2626),
                              size: 18.r,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'L\'identité des utilisateurs et l\'historique des échanges sont conservés pour être transmis aux autorités judiciaires en cas d\'arnaque, d\'extorsion ou de harcèlement.',
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: const Color(0xFF991B1B),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final currentUserId =
                                        _supabase.auth.currentUser?.id;
                                    await _supabase.from('job_reports').insert({
                                      if (currentUserId != null)
                                        'user_id': currentUserId,
                                      if (otherUserId != null)
                                        'reported_user_id': otherUserId,
                                      'reason': selectedReason,
                                      'details':
                                          detailsController.text
                                              .trim()
                                              .isNotEmpty
                                          ? detailsController.text.trim()
                                          : null,
                                    });

                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Votre signalement a été transmis à la modération.',
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } catch (err) {
                                    debugPrint('Error reporting user: $err');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Erreur : ${err.toString()}',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    setModalState(() => isSubmitting = false);
                                  }
                                },
                          icon: isSubmitting
                              ? SizedBox(
                                  width: 20.r,
                                  height: 20.r,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.flag_rounded,
                                  color: Colors.white,
                                ),
                          label: Text(
                            isSubmitting
                                ? 'Envoi...'
                                : 'Envoyer le signalement 🚨',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _supabase.auth.currentUser?.id;
    final otherName = widget.otherUserName ?? 'Discussion';
    final otherCompany = widget.otherUserCompany;

    // Use corporate blue theme if I am a Recruiter, orange theme if Candidate
    final Color primaryThemeColor = _isMeRecruiter
        ? const Color(0xFF1E3A8A)
        : const Color(0xFFF97316);
    final Color otherBubbleColor = const Color(0xFFF1F5F9);
    final Color myBubbleColor = primaryThemeColor;

    final initials = otherName
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: _getAvatarColor(otherName),
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (otherCompany != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      otherCompany,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: primaryThemeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFF64748B),
            ),
            tooltip: 'Supprimer la discussion',
            onPressed: () => _confirmDeleteChat(),
          ),
          IconButton(
            icon: const Icon(
              Icons.outlined_flag_rounded,
              color: Color(0xFFEF4444),
            ),
            tooltip: 'Signaler cet utilisateur',
            onPressed: () {
              final targetUserId = _isMeRecruiter ? _candidateId : _recruiterId;
              _showReportUserModal(
                context,
                otherUserId: targetUserId,
                otherName: otherName,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🛡️ Bannière de sécurité, éthique & avertissement judiciaire (adaptée au rôle)
          if (widget.isRecruiter == null && !_isContextLoaded)
            const SizedBox.shrink()
          else if (_isMeRecruiter)
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gavel_rounded,
                    color: const Color(0xFFD97706),
                    size: 20.r,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rappel Éthique, Bannissement & Poursuites',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '• Interdiction absolue d\'exiger de l\'argent ou des frais aux candidats.\n• Vos identifiants sont enregistrés. Toute arnaque, extorsion d\'argent ou harcèlement entraînera le BANNISSEMENT DÉFINITIF de votre compte et des poursuites judiciaires immédiates.',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: const Color(0xFFB45309),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: const Color(0xFFDC2626),
                    size: 20.r,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conseils de Sécurité & Protection Juridique',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '• Ne payez JAMAIS d\'argent (les recrutements sont 100% gratuits).\n• L\'identité du recruteur est enregistrée. Cliquez sur 🚩 pour signaler : toute fraude sera transmise aux autorités pour poursuites judiciaires.',
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: const Color(0xFFB91C1C),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryThemeColor),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFFCBD5E1),
                          size: 48.r,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Début de la discussion',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Envoyez un message pour commencer !',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 16.h,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isMe = msg['sender_id'] == userId;
                      final msgTime = _formatMessageTime(msg['created_at']);

                      return Dismissible(
                        key: Key('msg_${msg['id']}_$index'),
                        direction: DismissDirection.startToEnd,
                        confirmDismiss: (direction) async {
                          if (mounted) {
                            setState(() {
                              _replyingToMessage = msg;
                            });
                          }
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(left: 16.w),
                          margin: EdgeInsets.only(bottom: 8.h),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: primaryThemeColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.reply_rounded,
                              color: primaryThemeColor,
                              size: 20.r,
                            ),
                          ),
                        ),
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () =>
                                _showMessageOptionsSheet(msg, isMe),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8.h),
                              constraints: BoxConstraints(maxWidth: 0.75.sw),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? myBubbleColor : otherBubbleColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16.r),
                                  topRight: Radius.circular(16.r),
                                  bottomLeft: isMe
                                      ? Radius.circular(16.r)
                                      : Radius.zero,
                                  bottomRight: isMe
                                      ? Radius.zero
                                      : Radius.circular(16.r),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0F172A,
                                    ).withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (msg['is_deleted'] == true) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.block_rounded,
                                          size: 14.r,
                                          color: isMe
                                              ? Colors.white.withOpacity(0.7)
                                              : const Color(0xFF94A3B8),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          isMe
                                              ? 'Vous avez supprimé ce message'
                                              : 'Ce message a été supprimé',
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white.withOpacity(0.85)
                                                : const Color(0xFF64748B),
                                            fontSize: 13.sp,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    // Quoted Message Card if replying
                                    if (msg['reply_to_text'] != null) ...[
                                      Container(
                                        margin: EdgeInsets.only(bottom: 8.h),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 6.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.white.withOpacity(0.2)
                                              : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                          border: Border(
                                            left: BorderSide(
                                              color: isMe
                                                  ? Colors.white
                                                  : primaryThemeColor,
                                              width: 3.w,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              msg['reply_to_sender'] ??
                                                  'Message',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11.sp,
                                                color: isMe
                                                    ? Colors.white
                                                    : primaryThemeColor,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              msg['reply_to_text'] ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: isMe
                                                    ? Colors.white.withOpacity(
                                                        0.9,
                                                      )
                                                    : const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    if (msg['message_type'] == 'image') ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => Scaffold(
                                                  backgroundColor: Colors.black,
                                                  appBar: AppBar(
                                                    backgroundColor:
                                                        Colors.black,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                  ),
                                                  body: Center(
                                                    child: InteractiveViewer(
                                                      child: Image.network(
                                                        msg['media_url']!,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Image.network(
                                            msg['media_url']!,
                                            fit: BoxFit.cover,
                                            width: 180.w,
                                            height: 180.h,
                                            loadingBuilder:
                                                (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return Container(
                                                    width: 180.w,
                                                    height: 180.h,
                                                    color: Colors.grey.shade200,
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  );
                                                },
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: 180.w,
                                                      height: 180.h,
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ] else if (msg['message_type'] ==
                                        'audio') ...[
                                      _AudioPlayerBubble(
                                        audioUrl: msg['media_url']!,
                                        isMe: isMe,
                                        primaryColor: primaryThemeColor,
                                      ),
                                    ] else if (msg['message_type'] ==
                                        'pdf') ...[
                                      _PdfMessageBubble(
                                        pdfUrl: msg['media_url']!,
                                        fileName: msg['message'] ?? 'Document.pdf',
                                        isMe: isMe,
                                        primaryColor: primaryThemeColor,
                                      ),
                                    ] else ...[
                                      Text(
                                        msg['message'] ?? '',
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                          fontSize: 14.sp,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                  SizedBox(height: 4.h),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msgTime,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white.withOpacity(0.6)
                                              : const Color(0xFF94A3B8),
                                          fontSize: 9.sp,
                                        ),
                                      ),
                                      if (isMe &&
                                          msg['is_deleted'] != true) ...[
                                        SizedBox(width: 4.w),
                                        Icon(
                                          Icons.done_all,
                                          size: 11.r,
                                          color: msg['is_read'] == true
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.4),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Active Reply Preview Banner
          if (_replyingToMessage != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border(
                    left: BorderSide(color: primaryThemeColor, width: 4.w),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Réponse à ${_replyingToMessage!['sender_id'] == userId ? "Vous-même" : otherName}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              color: primaryThemeColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _replyingToMessage!['message_type'] == 'pdf'
                                ? '[Document PDF 📄]'
                                : (_replyingToMessage!['message_type'] ==
                                          'image'
                                      ? '[Photo 📸]'
                                      : (_replyingToMessage!['message_type'] ==
                                                'audio'
                                            ? '[Message Vocal 🎤]'
                                            : (_replyingToMessage!['message'] ??
                                                ''))),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingToMessage = null;
                        });
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 20.r,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Message Input Field
          SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Attachment buttons (Photo & PDF)
                  if (!_isRecording) ...[
                    IconButton(
                      icon: Icon(
                        Icons.add_photo_alternate_rounded,
                        color: primaryThemeColor,
                        size: 24.r,
                      ),
                      onPressed: _isLoadingMedia ? null : _sendImage,
                      tooltip: 'Envoyer une photo',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.picture_as_pdf_rounded,
                        color: primaryThemeColor,
                        size: 24.r,
                      ),
                      onPressed: _isLoadingMedia ? null : _sendPdfDocument,
                      tooltip: 'Envoyer un fichier PDF',
                    ),
                    SizedBox(width: 4.w),
                  ],

                  // Text input or Recording indicator
                  Expanded(
                    child: _isRecording
                        ? Container(
                            height: 48.h,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mic,
                                  color: const Color(0xFFEF4444),
                                  size: 20.r,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Enregistrement : ${_formatTimerDuration(Duration(seconds: _recordDuration))}',
                                  style: TextStyle(
                                    color: const Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: InputDecoration(
                                  hintText: 'Écrire un message...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 12.h,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24.r),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              if (_isLoadingMedia)
                                Positioned(
                                  right: 12.w,
                                  child: SizedBox(
                                    width: 18.r,
                                    height: 18.r,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryThemeColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  SizedBox(width: 10.w),

                  // Send or mic record button
                  GestureDetector(
                    onTap: _isLoadingMedia
                        ? null
                        : () {
                            if (_isRecording) {
                              _stopAndSendVoiceNote();
                            } else if (_messageController.text
                                .trim()
                                .isNotEmpty) {
                              _sendMessage();
                            } else {
                              _startRecording();
                            }
                          },
                    child: Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? const Color(0xFFEF4444)
                            : primaryThemeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording
                            ? Icons.stop_rounded
                            : (_messageController.text.trim().isNotEmpty
                                  ? Icons.send_rounded
                                  : Icons.mic_rounded),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioPlayerBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final Color primaryColor;

  const _AudioPlayerBubble({
    required this.audioUrl,
    required this.isMe,
    required this.primaryColor,
  });

  @override
  State<_AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}

class _AudioPlayerBubbleState extends State<_AudioPlayerBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _audioPlayer.setSource(UrlSource(widget.audioUrl));
      final dur = await _audioPlayer.getDuration();
      if (dur != null && mounted) {
        setState(() => _duration = dur);
      }

      _posSub = _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _durSub = _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });

      _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _completeSub = _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
          _audioPlayer.seek(Duration.zero);
        }
      });
    } catch (e) {
      debugPrint('Error initializing audio source: $e');
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_position == Duration.zero ||
            _position >= _duration - const Duration(milliseconds: 300) ||
            _audioPlayer.state == PlayerState.completed) {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      debugPrint('Error toggling play: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isMe ? Colors.white : widget.primaryColor;
    final textColor = widget.isMe ? Colors.white70 : const Color(0xFF64748B);

    final double maxVal = _duration.inMilliseconds.toDouble() > 0.0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final double sliderVal = _position.inMilliseconds.toDouble().clamp(
      0.0,
      maxVal,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          icon: Icon(
            _isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            color: themeColor,
            size: 36.r,
          ),
          onPressed: _togglePlay,
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120.w,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 10.r),
                  activeTrackColor: themeColor,
                  inactiveTrackColor: themeColor.withOpacity(0.3),
                  thumbColor: themeColor,
                ),
                child: Slider(
                  value: sliderVal,
                  min: 0.0,
                  max: maxVal,
                  onChanged: (val) {
                    _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: TextStyle(color: textColor, fontSize: 10.sp),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PdfMessageBubble extends StatefulWidget {
  final String pdfUrl;
  final String fileName;
  final bool isMe;
  final Color primaryColor;

  const _PdfMessageBubble({
    required this.pdfUrl,
    required this.fileName,
    required this.isMe,
    required this.primaryColor,
  });

  @override
  State<_PdfMessageBubble> createState() => _PdfMessageBubbleState();
}

class _PdfMessageBubbleState extends State<_PdfMessageBubble> {
  bool _isDownloading = false;

  Future<void> _openOrDownloadPdf() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = widget.fileName
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final cleanFileName = sanitizedName.endsWith('.pdf')
          ? sanitizedName
          : '$sanitizedName.pdf';
      final filePath = '${tempDir.path}/$cleanFileName';
      final localFile = File(filePath);

      // Download PDF bytes if not cached locally
      if (!await localFile.exists()) {
        final response = await http.get(Uri.parse(widget.pdfUrl));
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Erreur de téléchargement (${response.statusCode})');
        }
      }

      // Open local PDF with OS native viewer
      try {
        final openResult = await OpenFilex.open(filePath);
        if (openResult.type != ResultType.done) {
          final Uri uri = Uri.parse(widget.pdfUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } catch (openErr) {
        debugPrint('OpenFilex plugin fallback to url_launcher: $openErr');
        final Uri uri = Uri.parse(widget.pdfUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error downloading/opening PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'ouverture du PDF : ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBgColor = widget.isMe
        ? Colors.white.withOpacity(0.18)
        : const Color(0xFFE2E8F0);
    final textColor = widget.isMe ? Colors.white : const Color(0xFF0F172A);
    final subtextColor =
        widget.isMe ? Colors.white.withOpacity(0.8) : const Color(0xFF64748B);
    final iconColor = widget.isMe ? Colors.white : const Color(0xFFEF4444);

    return InkWell(
      onTap: _openOrDownloadPdf,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: _isDownloading
                  ? SizedBox(
                      width: 24.r,
                      height: 24.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      Icons.picture_as_pdf_rounded,
                      color: iconColor,
                      size: 24.r,
                    ),
            ),
            SizedBox(width: 10.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isDownloading
                            ? Icons.downloading_rounded
                            : Icons.download_rounded,
                        size: 12.r,
                        color: subtextColor,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _isDownloading
                            ? 'Téléchargement...'
                            : 'Télécharger & Lire',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
