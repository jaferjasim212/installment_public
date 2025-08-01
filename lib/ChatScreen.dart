import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart'; // ✅ استيراد مكتبة shimmer

class ChatScreen extends StatefulWidget {
  final int workshopId; // استقبال معرف الورشة

  const ChatScreen({super.key, required this.workshopId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _messages = [];
  String? userId;
  String? auth_user_id;
  @override
  void initState() {
    super.initState();
    _loadUserIdAndSubscribe(); // ✅ استدعاء دالة جديدة تتأكد من تحميل userId أولًا
    fetchWorkshopName(); // ✅ جلب اسم الورشة عند فتح الشاشة
  }

  /// ✅ دالة جديدة لتحميل `userId` ثم تشغيل `subscribe`
  Future<void> _loadUserIdAndSubscribe() async {
    await _loadUserId(); // ✅ انتظار تحميل userId
    if (userId != null) {
      _subscribeToMessages(); // ✅ تشغيل الاشتراك بعد التأكد من أن userId ليس null
    }
  }

  void _subscribeToMessages() {
    if (userId == null) return;
    supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            try {
              final newMessage = payload.newRecord;

              // تأكد من أن البيانات موجودة
              // ignore: unnecessary_null_comparison
              if (newMessage == null || newMessage['id'] == null) {
                print('⚠️ رسالة جديدة ولكنها غير صالحة: $newMessage');
                return;
              }

              // تحقق من الحقول الأساسية
              if (!(newMessage.containsKey('sender_id') &&
                  newMessage.containsKey('receiver_id') &&
                  newMessage.containsKey('content'))) {
                print('⚠️ الحقول ناقصة في الرسالة: $newMessage');
                return;
              }

              // شرط ظهور الرسالة
              if (newMessage['receiver_id'].toString() == userId ||
                  newMessage['sender_id'].toString() == userId) {
                setState(() {
                  if (!_messages.any((msg) => msg['id'] == newMessage['id'])) {
                    _messages.insert(0, Map<String, dynamic>.from(newMessage));
                  }
                });

                _markConversationAsRead();
              }
            } catch (e, stackTrace) {
              print('❌ حدث استثناء أثناء استقبال رسالة مباشرة: $e');
              print(stackTrace);
            }
          },
        )
        .subscribe();
  }

  Future<void> _markConversationAsRead() async {
    if (userId == null) return;

    try {
      await supabase.from('conversations').update({'state': true}).match({
        'sender_id': userId!,
        'receiver_id': widget.workshopId,
        // ignore: avoid_print
      });
    } catch (e) {
      print("❌ فشل في تحديث حالة المحادثة: $e");
    }
  }

  Future<void> _loadUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      auth_user_id =
          prefs.getString('UserID'); // جلب auth_user_id من SharedPreferences

      if (auth_user_id != null) {
        print(
            "🔍 البحث عن UserID في PersonalAccount باستخدام auth_user_id: $auth_user_id");

        final response = await Supabase.instance.client
            .from('PersonalAccount')
            .select('UserID') // جلب UserID فقط
            .eq('auth_user_id', auth_user_id!.toString())
            .single(); // جلب سجل واحد فقط

        // ignore: unnecessary_null_comparison
        if (response != null && response.containsKey('UserID')) {
          setState(() {
            userId = response['UserID'].toString(); // ✅ تحويل الرقم إلى نص
          });
          print("✅ تم جلب UserID بنجاح: $userId");
          _markConversationAsRead();

          _loadChatHistory();
        } else {
          print("⚠️ لم يتم العثور على UserID في قاعدة البيانات لهذا المستخدم.");
        }
      } else {
        print("⚠️ لم يتم العثور على auth_user_id في SharedPreferences.");
      }
    } catch (e) {
      print("❌ خطأ أثناء جلب UserID: $e");
    }
  }

  int _limit = 10; // عدد الرسائل المحملة في كل مرة
  bool _isLoadingMore = false; // للتحكم في تحميل المزيد من الرسائل
  bool _allMessagesLoaded =
      false; // لمعرفة ما إذا كانت كل الرسائل قد تم تحميلها

  Future<void> _loadChatHistory({bool loadMore = false}) async {
    if (_isLoadingMore) return; // تجنب التحميل المكرر

    try {
      if (!loadMore) {
        _messages.clear(); // إذا كانت تحميل أول مرة، يتم إعادة تعيين القائمة
        _allMessagesLoaded = false;
      }

      _isLoadingMore = true;

      print("📩 جلب ${loadMore ? 'المزيد من' : 'أحدث'} الرسائل...");

      final response = await supabase
          .from('messages')
          .select('*')
          .or(
              'and(sender_id.eq.$userId,receiver_id.eq.${widget.workshopId}),and(sender_id.eq.${widget.workshopId},receiver_id.eq.$userId)')
          .order('timestamp', ascending: false) // ✅ جلب الأحدث أولاً
          .range(_messages.length,
              _messages.length + _limit - 1); // ✅ جلب ٢٠ رسالة فقط

      if (response.isEmpty) {
        _allMessagesLoaded = true; // لم يعد هناك رسائل أخرى للتحميل
        print("✅ تم تحميل كل الرسائل.");
      } else {
        _messages.addAll(List<Map<String, dynamic>>.from(response));
      }

      if (mounted) {
        setState(() {});
      }

      print("✅ تم جلب ${response.length} رسالة.");
    } catch (error) {
      print('❌ خطأ أثناء جلب الرسائل: $error');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || userId == null) return;

    final messageText = _messageController.text;
    _messageController.clear();

    final newMessage = {
      'sender_id': userId,
      'receiver_id': widget.workshopId,
      'content': messageText,
      'type': 'text',
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'sent',
    };

    try {
      // ✅ إدراج الرسالة في قاعدة البيانات (دون إضافتها يدويًا إلى _messages)
      await supabase.from('messages').insert(newMessage);

      // ✅ تحديث أو إدراج المحادثة في جدول conversations
      await supabase.from('conversations').upsert(
        {
          'sender_id': userId,
          'receiver_id': widget.workshopId,
          'last_message': messageText,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'sender_id,receiver_id',
      );

      print("✅ تم إرسال الرسالة بنجاح");
    } catch (error) {
      print('❌ خطأ أثناء إرسال الرسالة: $error');
    }
  }

  String? workshopName; // متغير لتخزين اسم الورشة

  Future<void> fetchWorkshopName() async {
    try {
      final response = await supabase
          .from('Workshops') // ✅ اسم الجدول الذي يحتوي على بيانات الورش
          .select('workshopname') // ✅ جلب فقط اسم الورشة
          .eq('WorkshopID', widget.workshopId) // ✅ البحث باستخدام الـ ID
          .maybeSingle(); // ✅ جلب سجل واحد فقط

      if (response != null && response['workshopname'] != null) {
        setState(() {
          workshopName = response['workshopname']; // ✅ تخزين الاسم في المتغير
        });
      } else {
        print("⚠️ لم يتم العثور على اسم الورشة");
      }
    } catch (e) {
      print("❌ خطأ أثناء جلب اسم الورشة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          workshopName ??
              'تحميل...', // ✅ عرض اسم الورشة أو "تحميل..." إذا لم يتم جلب الاسم بعد
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true, // ✅ جعل العنوان في المنتصف
        backgroundColor: Colors.teal.shade800,
        elevation: 5, // ✅ إضافة تأثير ظل لجمالية أكثر
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()), // ✅ إدراج المحادثة بالخلفية
          _buildMessageInput(), // ✅ إدراج حقل إدخال الرسائل
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
              'assets/images/chatbackground.png'), // ✅ تحديد صورة الخلفية
          fit: BoxFit.cover, // ✅ جعل الخلفية تغطي كامل الشاشة
        ),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
              !_isLoadingMore &&
              !_allMessagesLoaded) {
            _loadChatHistory(
                loadMore: true); // ✅ تحميل المزيد عند التمرير للأعلى
          }
          return false;
        },
        child: _messages.isEmpty
            ? _isLoadingMore
                ? _buildShimmerLoading() // ✅ إظهار تأثير التحميل أثناء تحميل الرسائل
                : const Center(
                    child: Text(
                      'لا توجد رسائل بعد',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  )
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                reverse: true,
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _isLoadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : _allMessagesLoaded
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text(
                                    "✅ تم تحميل جميع الرسائل.",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                            : Container();
                  }

                  final message = _messages[index];
                  final bool isSentByMe =
                      message['sender_id'].toString() == userId;

                  return Align(
                    alignment: isSentByMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSentByMe
                            ? Colors.teal.shade800
                            : Colors.grey[300],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(15),
                          topRight: const Radius.circular(15),
                          bottomLeft: isSentByMe
                              ? const Radius.circular(15)
                              : Radius.zero,
                          bottomRight: isSentByMe
                              ? Radius.zero
                              : const Radius.circular(15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['content'],
                            style: TextStyle(
                              fontSize: 16,
                              color: isSentByMe ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _formatTimestamp(message['timestamp']),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isSentByMe ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// ✅ تأثير Shimmer أثناء تحميل الرسائل
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: 6, // ✅ عدد العناصر الوهمية أثناء التحميل
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textDirection: TextDirection.rtl, // ✅ جعل الكتابة تبدأ من اليمين
              textAlign: TextAlign.right, // ✅ محاذاة النص إلى اليمين
              decoration: InputDecoration(
                hintText: "اكتب رسالتك...",
                hintTextDirection: TextDirection.rtl, // ✅ جعل التلميح من اليمين
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.teal),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    DateTime date = DateTime.parse(timestamp);
    return "${date.hour}:${date.minute}";
  }
}
