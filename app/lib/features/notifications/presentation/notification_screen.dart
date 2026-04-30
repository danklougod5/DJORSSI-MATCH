import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  Set<String> _deletedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDeletedIds().then((_) => _fetchNotifications());
  }

  Future<void> _loadDeletedIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deletedIds = (prefs.getStringList('deleted_notifications') ?? []).toSet();
    });
  }

  Future<void> _saveDeletedId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _deletedIds.add(id);
    await prefs.setStringList('deleted_notifications', _deletedIds.toList());
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        // Filtrer les notifications supprimées localement
        _notifications = response.where((n) => !_deletedIds.contains(n['id'].toString())).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du chargement des notifications')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: _fetchNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final notifId = notif['id'].toString();

                    return Dismissible(
                      key: Key(notifId),
                      direction: DismissDirection.endToStart, // Droite vers Gauche
                      onDismissed: (direction) {
                        _saveDeletedId(notifId);
                        setState(() {
                          _notifications.removeAt(index);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notification supprimée'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      background: _buildDeleteBackground(),
                      child: _buildNotificationCard(notif),
                    );
                  },
                ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.only(right: 20.w),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 80.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            'Aucune notification pour le moment',
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notif) {
    final DateTime date = DateTime.parse(notif['created_at']);
    final String formattedDate = DateFormat('dd MMM, HH:mm', 'fr_FR').format(date);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8200).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active, color: Color(0xFFFF8200), size: 20),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notif['title'] ?? 'Notification',
                        style: GoogleFonts.outfit(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  notif['body'] ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
