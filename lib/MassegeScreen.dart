import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  String? userId;
  String? auth_user_id;
  bool isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _channel = supabase.channel('realtime:conversations');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            print("📱 تحديث مباشر: ${payload.newRecord}");
            _loadConversations();
          },
        )
        .subscribe();
  }

  Future<void> _loadUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      auth_user_id = prefs.getString('UserID');

      if (auth_user_id != null) {
        final response = await Supabase.instance.client
            .from('PersonalAccount')
            .select('UserID')
            .eq('auth_user_id', auth_user_id!)
            .single();

        // ignore: unnecessary_null_comparison
        if (response != null && response.containsKey('UserID')) {
          setState(() {
            userId = response['UserID'].toString();
          });
          _loadConversations();
          _setupRealtimeSubscription();
        }
      }
    } catch (e) {
      print("❌ خطأ أثناء جلب UserID: $e");
    }
  }

  Future<void> _loadConversations() async {
    try {
      final response = await supabase
          .from('conversations')
          .select('*')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId');

      final conversations = List<Map<String, dynamic>>.from(response);

      for (var conversation in conversations) {
        final workshopId = conversation['receiver_id'] == userId
            ? conversation['sender_id']
            : conversation['receiver_id'];

        final workshopResponse = await supabase
            .from('Workshops')
            .select('WorkshopID,workshopname, workshopimage')
            .eq('WorkshopID', workshopId)
            .single();

        conversation['workshop'] = workshopResponse;
      }

      conversations.sort((a, b) => DateTime.parse(b['updated_at'])
          .compareTo(DateTime.parse(a['updated_at'])));

      setState(() {
        _conversations = conversations;
        isLoading = false;
      });
    } catch (error) {
      print('Error fetching conversations: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المحادثات',
          style: TextStyle(fontSize: 25, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade800,
        centerTitle: true,
      ),
      body: isLoading
          ? _buildShimmerLoader()
          : _conversations.isEmpty
              ? const Center(
                  child: Text('لا توجد محادثات بعد',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    final workshop = conversation['workshop'];
                    final workshopId = workshop['WorkshopID'];
                    final workshopName = workshop['workshopname'];
                    final workshopImageBase64 = workshop['workshopimage'];
                    final lastMessage = conversation['last_message'];
                    final updatedAt = conversation['updated_at'];
                    final isUnread = conversation['state'] == false;

                    return GestureDetector(
                      onTap: () {

                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    backgroundImage: MemoryImage(
                                      base64Decode(workshopImageBase64),
                                    ),
                                    radius: 35,
                                  ),
                                  if (isUnread)
                                    Positioned(
                                      top: 0,
                                      right: -2,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      workshopName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: isUnread
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isUnread
                                            ? Colors.black
                                            : Colors.teal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      lastMessage,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isUnread
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isUnread
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                children: [
                                  Text(
                                    _formatTimestamp(updatedAt),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isUnread
                                          ? Colors.black
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildShimmerLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: MediaQuery.of(context).size.width * 0.5,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 50,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(String timestamp) {
    DateTime date = DateTime.parse(timestamp);
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}";
  }
}
