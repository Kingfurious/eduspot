import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'message.dart';
import 'Chat_screen.dart';
import 'Services/presence_service.dart';

// Modern Instagram-style Messages Screen
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with SingleTickerProviderStateMixin {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  final PresenceService _presenceService = PresenceService();

  // Keep a cache of user data to avoid repeated fetches
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Keep track of chats with their last message timestamp for sorting
  final Map<String, Timestamp> _chatTimestamps = {};

  // Selection mode variables
  bool _isSelectionMode = false;
  final Set<String> _selectedChats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _presenceService.dispose();
    super.dispose();
  }

  // Enter selection mode
  void _enterSelectionMode(String chatId) {
    setState(() {
      _isSelectionMode = true;
      _selectedChats.add(chatId);
    });
  }

  // Exit selection mode
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChats.clear();
    });
  }

  // Toggle chat selection
  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChats.contains(chatId)) {
        _selectedChats.remove(chatId);
        if (_selectedChats.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChats.add(chatId);
      }
    });
  }

  // Delete selected chats
  Future<void> _deleteSelectedChats() async {
    if (currentUser == null) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (String chatId in _selectedChats) {
        // Update the chat document to mark it as deleted for current user
        DocumentReference chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
        batch.update(chatRef, {
          'deletedBy': FieldValue.arrayUnion([currentUser!.uid]),
          'lastDeleted.${currentUser!.uid}': Timestamp.now(),
        });
      }

      await batch.commit();
      _exitSelectionMode();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedChats.length} chats deleted'),
          backgroundColor: AppColors.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error deleting chats: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete chats'),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Show options menu for selected chats
  void _showSelectedChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionTile(
              icon: Icons.delete_outline,
              title: 'Delete',
              color: AppColors.errorColor,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog();
              },
            ),
            _buildOptionTile(
              icon: Icons.visibility_off_outlined,
              title: 'Hide',
              onTap: () {
                Navigator.pop(context);
                _showHideConfirmationDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete ${_selectedChats.length} ${_selectedChats.length == 1 ? 'chat' : 'chats'}?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete these conversations for you.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedChats();
            },
            child: Text('Delete', style: TextStyle(color: AppColors.errorColor)),
          ),
        ],
      ),
    );
  }

  // Show hide confirmation dialog
  void _showHideConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Hide ${_selectedChats.length} ${_selectedChats.length == 1 ? 'chat' : 'chats'}?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Hidden chats will not appear in your chat list but you can reveal them.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _hideSelectedChats();
            },
            child: Text('Hide', style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  // Hide selected chats
  Future<void> _hideSelectedChats() async {
    if (currentUser == null) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (String chatId in _selectedChats) {
        // Update the chat document to mark it as hidden for current user
        DocumentReference chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
        batch.update(chatRef, {
          'hiddenBy': FieldValue.arrayUnion([currentUser!.uid]),
          'lastHidden.${currentUser!.uid}': Timestamp.now(),
        });
      }

      await batch.commit();
      _exitSelectionMode();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedChats.length} chats hidden'),
          backgroundColor: AppColors.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error hiding chats: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to hide chats'),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Fetch user data with caching
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    Map<String, dynamic> userData = {
      'name': 'Unknown User',
      'photoURL': null,
      'lastActive': null,
    };

    try {
      // Try users collection first
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        userData['name'] = _normalizeName(data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'] ??
            data['username'] ??
            'Unknown User');
        userData['photoURL'] = data['imageUrl'] ??
            data['photoURL'] ??
            data['profilePic'] ??
            data['avatar'];
        userData['lastActive'] = data['lastActive'];
        _userCache[userId] = userData;
        return userData;
      }

      // Fallback to studentprofile collection
      doc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        userData['name'] = _normalizeName(data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'] ??
            'Unknown User');
        userData['photoURL'] = data['imageUrl'] ??
            data['photoURL'] ??
            data['profilePic'] ??
            data['avatar'];
        userData['lastActive'] = data['lastActive'];
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      print("Error fetching user data for $userId: $e");
    }

    _userCache[userId] = userData;
    return userData;
  }

  // Normalize names for consistency
  String _normalizeName(String name) {
    return name.trim().split(' ').map((word) =>
    word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
    ).join(' ').trim();
  }

  // Validate image URL
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    if (url.contains('images.app.goo.gl') ||
        url.contains('google.com/images') ||
        url.contains('gstatic.com/images')) {
      return false;
    }
    bool isValidUrl = url.startsWith('http://') || url.startsWith('https://');
    if (isValidUrl) {
      String lowercaseUrl = url.toLowerCase();
      bool hasImageExtension = lowercaseUrl.endsWith('.jpg') ||
          lowercaseUrl.endsWith('.jpeg') ||
          lowercaseUrl.endsWith('.png') ||
          lowercaseUrl.endsWith('.gif') ||
          lowercaseUrl.endsWith('.webp');
      return hasImageExtension ||
          lowercaseUrl.contains('firebasestorage.googleapis.com') ||
          lowercaseUrl.contains('storage.googleapis.com');
    }
    return false;
  }

  // Format message time
  String _formatMessageTime(Timestamp timestamp) {
    DateTime messageTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (messageTime.year == now.year &&
        messageTime.month == now.month &&
        messageTime.day == now.day) {
      return DateFormat('h:mm a').format(messageTime);
    }
    DateTime yesterday = now.subtract(Duration(days: 1));
    if (messageTime.year == yesterday.year &&
        messageTime.month == yesterday.month &&
        messageTime.day == yesterday.day) {
      return 'Yesterday';
    }
    if (now.difference(messageTime).inDays < 7) {
      return DateFormat('E').format(messageTime);
    }
    if (messageTime.year == now.year) {
      return DateFormat('MMM d').format(messageTime);
    }
    return DateFormat('MMM d, y').format(messageTime);
  }

  // Check for unread messages (placeholder)
  bool _hasUnreadMessages(String chatId) {
    return chatId.hashCode % 3 == 0;
  }

  // Modified Chat List Tile with selection capability
  Widget _buildChatListTile({
    required BuildContext context,
    required String chatId,
    required String otherUserId,
    required String otherUserName,
    String? photoURL,
    Timestamp? lastMessageTime,
    bool isFirst = false,
  }) {
    final String firstLetter = otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U';
    bool hasValidImage = _isValidImageUrl(photoURL);
    bool isOnline = _presenceService.isUserOnline(_userCache[otherUserId]?['lastActive']);
    bool isSelected = _selectedChats.contains(chatId);

    return Container(
      margin: EdgeInsets.fromLTRB(16, isFirst ? 0 : 8, 16, 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: AppColors.primaryBlue, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor.withOpacity(0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                backgroundImage: hasValidImage ? NetworkImage(photoURL!) : null,
                child: !hasValidImage
                    ? Text(
                  firstLetter,
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                )
                    : null,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 2,
                bottom: 5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.successColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cardBackground,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor.withOpacity(0.1),
                        blurRadius: 2,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isSelectionMode)
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryBlue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUserName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastMessageTime != null)
              Text(
                _formatMessageTime(lastMessageTime),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        subtitle: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, msgSnapshot) {
            if (!msgSnapshot.hasData || msgSnapshot.data!.docs.isEmpty) {
              return Text(
                'Start a conversation',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              );
            }

            try {
              var lastMessageData = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>?;
              if (lastMessageData == null) {
                return Text('...', style: TextStyle(color: AppColors.textSecondary));
              }

              if (lastMessageData['timestamp'] != null) {
                Timestamp timestamp = lastMessageData['timestamp'] as Timestamp;
                _chatTimestamps[chatId] = timestamp;
              }

              var lastMessage = Message.fromMap(lastMessageData);
              bool isLastMessageFromMe = lastMessage.senderId == currentUser?.uid;

              String previewText = '';
              if (lastMessage.type == 'text') {
                previewText = lastMessage.content ?? '';
              } else if (lastMessage.type == 'image') {
                previewText = '📷 Photo';
              } else if (lastMessage.type == 'video') {
                previewText = '🎥 Video';
              } else if (lastMessage.type == 'audio') {
                previewText = '🎵 Audio';
              } else if (lastMessage.type == 'deleted') {
                previewText = 'Message was deleted';
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      "${isLastMessageFromMe ? 'You: ' : ''}$previewText",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isLastMessageFromMe && _hasUnreadMessages(chatId))
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              );
            } catch (e) {
              print("Error parsing last message for chat $chatId: $e");
              return Text(
                'Error loading message',
                style: TextStyle(color: AppColors.errorColor, fontSize: 13),
              );
            }
          },
        ),
        onTap: () {
          if (_isSelectionMode) {
            _toggleChatSelection(chatId);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  otherUserId: otherUserId,
                  otherUserName: otherUserName,
                ),
              ),
            );
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            _enterSelectionMode(chatId);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return _buildAuthRequiredScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isSearching) _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMessagesTab(),
                _buildActiveUsersTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: !_isSelectionMode ? NewMessageButton() : null,
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar() : null,
    );
  }

  // Bottom bar for selection mode
  Widget _buildSelectionBottomBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: () => _exitSelectionMode(),
            icon: Icon(Icons.close, color: AppColors.textSecondary),
            label: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.withOpacity(0.3),
          ),
          Text(
            '${_selectedChats.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey.withOpacity(0.3),
          ),
          TextButton.icon(
            onPressed: () => _showSelectedChatOptions(),
            icon: Icon(Icons.more_horiz, color: AppColors.primaryBlue),
            label: Text('Options', style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  // Authentication Required Screen
  Widget _buildAuthRequiredScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: Text('Messages', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          margin: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                color: AppColors.primaryBlue,
                size: 56,
              ),
              SizedBox(height: 16),
              Text(
                'Authentication Required',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Please log in to view your messages',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text("Go Back"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modified Instagram-style AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryBlue,
      elevation: 0,
      title: _isSearching
          ? null
          : Row(
        children: [
          Text(
            _isSelectionMode
                ? '${_selectedChats.length} selected'
                : 'Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          if (!_isSelectionMode) SizedBox(width: 4),
          if (!_isSelectionMode) Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
        ],
      ),
      leading: IconButton(
        icon: Icon(
          _isSearching || _isSelectionMode ? Icons.arrow_back : Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () {
          if (_isSearching) {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchQuery = '';
            });
          } else if (_isSelectionMode) {
            _exitSelectionMode();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        if (!_isSearching && !_isSelectionMode)
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
        if (!_isSelectionMode)
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showOptionsMenu(context);
            },
          ),
      ],
    );
  }

  // Search Bar Widget
  Widget _buildSearchBar() {
    return Container(
      color: AppColors.primaryBlue,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white70),
          ),
          autofocus: true,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  // Tab Bar
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        tabs: [
          Tab(text: 'Messages'),
          Tab(text: 'Active'),
        ],
      ),
    );
  }

  // Messages Tab - Main Chat List
  Widget _buildMessagesTab() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser?.uid ?? 'no-user')
        .snapshots(),
    builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
    return _buildLoadingState();
    }

    if (snapshot.hasError) {
    print("Error fetching chats: ${snapshot.error}");
    return _buildErrorState('Unable to load your conversations');
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
    return _buildEmptyState();
    }

    var chatDocs = snapshot.data!.docs;

    // Filter out deleted and hidden chats
    chatDocs = chatDocs.where((doc) {
    var chatData = doc.data() as Map<String, dynamic>?;
    if (chatData == null) return false;

    // Check if chat is deleted for current user
    List deletedBy = chatData['deletedBy'] ?? [];
    if (deletedBy.contains(currentUser?.uid)) return false;

    // Check if chat is hidden for current user
    List hiddenBy = chatData['hiddenBy'] ?? [];
    if (hiddenBy.contains(currentUser?.uid)) return false;

    return true;
    }).toList();

    return FutureBuilder<List<MapEntry<DocumentSnapshot, Timestamp>>>(
      future: _getSortedChats(chatDocs),
      builder: (context, sortedChatsSnapshot) {
        if (sortedChatsSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!sortedChatsSnapshot.hasData || sortedChatsSnapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        var sortedChats = sortedChatsSnapshot.data!;

        if (_searchQuery.isNotEmpty) {
          return FutureBuilder<List<MapEntry<DocumentSnapshot, Timestamp>>>(
            future: _filterChatsBySearchQuery(sortedChats, _searchQuery),
            builder: (context, filteredChatsSnapshot) {
              if (filteredChatsSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (!filteredChatsSnapshot.hasData || filteredChatsSnapshot.data!.isEmpty) {
                return _buildNoSearchResultsState();
              }

              return _buildChatList(filteredChatsSnapshot.data!);
            },
          );
        }

        return _buildChatList(sortedChats);
      },
    );
    },
    );
  }

  // Active Users Tab
  Widget _buildActiveUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('lastActive', isGreaterThan: Timestamp.fromDate(
        DateTime.now().subtract(Duration(minutes: 5)),
      ))
          .limit(50) // Limit to 50 users for efficiency
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        if (snapshot.hasError) {
          return _buildErrorState('Error loading active users');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: AppColors.primaryBlue.withOpacity(0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'No Active Users',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'No users are currently online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        var users = snapshot.data!.docs.where((doc) => doc.id != currentUser?.uid).toList();

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: AppColors.primaryBlue.withOpacity(0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'No Active Users',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'No users are currently online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;
            String userId = users[index].id;
            String userName = _normalizeName(userData['fullName'] ??
                userData['name'] ??
                userData['displayName'] ??
                userData['userName'] ??
                userData['username'] ??
                'Unknown User');
            String? photoURL = userData['imageUrl'] ??
                userData['photoURL'] ??
                userData['profilePic'] ??
                userData['avatar'];

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                backgroundImage: _isValidImageUrl(photoURL) ? NetworkImage(photoURL!) : null,
                child: !_isValidImageUrl(photoURL)
                    ? Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                )
                    : null,
              ),
              title: Text(
                userName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              trailing: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      otherUserId: userId,
                      otherUserName: userName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Chat List Builder
  Widget _buildChatList(List<MapEntry<DocumentSnapshot, Timestamp>> sortedChats) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: sortedChats.length,
      itemBuilder: (context, index) {
        var chatDoc = sortedChats[index].key;
        var lastMessageTime = sortedChats[index].value;
        var chatData = chatDoc.data() as Map<String, dynamic>?;
        String chatId = chatDoc.id;

        if (chatData == null || chatData['participants'] == null || !(chatData['participants'] is List)) {
          return SizedBox.shrink();
        }

        List<dynamic> participants = chatData['participants'];
        String? otherUserId = participants.firstWhere(
              (id) => id != currentUser?.uid && id != null,
          orElse: () => null,
        );

        if (otherUserId == null) {
          return SizedBox.shrink();
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _getUserData(otherUserId),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildChatListTileShimmer(isFirst: index == 0);
            }

            String otherUserName = 'Unknown User';
            String? photoURL;
            Timestamp? lastActive;

            if (userSnapshot.hasData) {
              final userData = userSnapshot.data!;
              otherUserName = userData['name'] ?? 'Unknown User';
              photoURL = userData['photoURL'];
              lastActive = userData['lastActive'];
            }

            return _buildChatListTile(
              context: context,
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              photoURL: photoURL,
              lastMessageTime: lastMessageTime,
              isFirst: index == 0,
            );
          },
        );
      },
    );
  }

  // Shimmer Effect for Loading Chat Tiles
  Widget _buildChatListTileShimmer({bool isFirst = false}) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, isFirst ? 0 : 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor.withOpacity(0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  color: AppColors.veryLightBlue,
                ),
              ),
            ),
          ],
        ),
        title: Container(
          width: 150,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.veryLightBlue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          margin: EdgeInsets.only(top: 8),
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.veryLightBlue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // Loading State
  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
      ),
    );
  }

  // Error State
  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 70,
            color: AppColors.errorColor.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              setState(() {});
            },
            child: Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.veryLightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: AppColors.primaryBlue,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start chatting with your connections!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              _navigateToNewMessageScreen(context);
            },
            child: Text('Find People', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // No Search Results State
  Widget _buildNoSearchResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 70,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No matches found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find any conversations matching "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Navigate to New Message Screen
  void _navigateToNewMessageScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewMessageScreen(),
      ),
    );
  }

  // Updated Options Menu
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionTile(
              icon: Icons.person_add,
              title: 'New message',
              onTap: () {
                Navigator.pop(context);
                _navigateToNewMessageScreen(context);
              },
            ),
            _buildOptionTile(
              icon: Icons.visibility,
              title: 'Show hidden chats',
              onTap: () {
                Navigator.pop(context);
                _showHiddenChats();
              },
            ),
            _buildOptionTile(
              icon: Icons.help_outline,
              title: 'Help & feedback',
              onTap: () {
                Navigator.pop(context);
                _showHelpAndFeedbackDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show hidden chats
  void _showHiddenChats() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Hidden Chats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .where('participants', arrayContains: currentUser?.uid ?? 'no-user')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No hidden chats'));
                    }

                    var hiddenChats = snapshot.data!.docs.where((doc) {
                      var chatData = doc.data() as Map<String, dynamic>?;
                      if (chatData == null) return false;
                      List hiddenBy = chatData['hiddenBy'] ?? [];
                      return hiddenBy.contains(currentUser?.uid);
                    }).toList();

                    if (hiddenChats.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_off,
                              size: 48,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No hidden chats',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: hiddenChats.length,
                      itemBuilder: (context, index) {
                        var chatDoc = hiddenChats[index];
                        var chatData = chatDoc.data() as Map<String, dynamic>;
                        String chatId = chatDoc.id;

                        List<dynamic> participants = chatData['participants'];
                        String? otherUserId = participants.firstWhere(
                              (id) => id != currentUser?.uid && id != null,
                          orElse: () => null,
                        );

                        if (otherUserId == null) return SizedBox.shrink();

                        return FutureBuilder<Map<String, dynamic>>(
                          future: _getUserData(otherUserId),
                          builder: (context, userSnapshot) {
                            String otherUserName = 'Unknown User';
                            String? photoURL;

                            if (userSnapshot.hasData) {
                              final userData = userSnapshot.data!;
                              otherUserName = userData['name'] ?? 'Unknown User';
                              photoURL = userData['photoURL'];
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                                backgroundImage: _isValidImageUrl(photoURL) ? NetworkImage(photoURL!) : null,
                                child: !_isValidImageUrl(photoURL)
                                    ? Text(
                                  otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                    : null,
                              ),
                              title: Text(
                                otherUserName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              trailing: TextButton(
                                child: Text(
                                  'Unhide',
                                  style: TextStyle(color: AppColors.primaryBlue),
                                ),
                                onPressed: () async {
                                  // Unhide the chat
                                  await FirebaseFirestore.instance
                                      .collection('chats')
                                      .doc(chatId)
                                      .update({
                                    'hiddenBy': FieldValue.arrayRemove([currentUser!.uid]),
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Chat restored'),
                                      backgroundColor: AppColors.successColor,
                                    ),
                                  );
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      otherUserId: otherUserId,
                                      otherUserName: otherUserName,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Help and Feedback Dialog
  void _showHelpAndFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    final ValueNotifier<bool> isSubmitting = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Help & Feedback',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help or want to share feedback? Let us know!',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter your feedback or question...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryBlue),
                    ),
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isSubmitting,
              builder: (context, submitting, _) {
                return TextButton(
                  onPressed: submitting
                      ? null
                      : () async {
                    if (feedbackController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter feedback before submitting.'),
                          backgroundColor: AppColors.errorColor,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    isSubmitting.value = true;
                    try {
                      await FirebaseFirestore.instance.collection('feedback').add({
                        'userId': currentUser?.uid ?? 'anonymous',
                        'feedback': feedbackController.text.trim(),
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Feedback submitted successfully!'),
                          backgroundColor: AppColors.successColor,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      print('Error submitting feedback: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit feedback. Please try again.'),
                          backgroundColor: AppColors.errorColor,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } finally {
                      isSubmitting.value = false;
                    }
                  },
                  child: submitting
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    ),
                  )
                      : Text(
                    'Submit',
                    style: TextStyle(color: AppColors.primaryBlue),
                  ),
                );
              },
            ),
          ],
        );
      },
    ).whenComplete(() {
      feedbackController.dispose();
      isSubmitting.dispose();
    });
  }

  // Option Tile
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primaryBlue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? AppColors.primaryBlue),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  // Get Sorted Chats
  Future<List<MapEntry<DocumentSnapshot, Timestamp>>> _getSortedChats(List<QueryDocumentSnapshot> chatDocs) async {
    List<MapEntry<DocumentSnapshot, Timestamp>> chatsWithTimestamps = [];

    for (var chatDoc in chatDocs) {
      String chatId = chatDoc.id;

      if (_chatTimestamps.containsKey(chatId)) {
        chatsWithTimestamps.add(MapEntry(chatDoc, _chatTimestamps[chatId]!));
        continue;
      }

      try {
        QuerySnapshot messagesQuery = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (messagesQuery.docs.isNotEmpty) {
          var lastMessageData = messagesQuery.docs.first.data() as Map<String, dynamic>?;
          if (lastMessageData != null && lastMessageData['timestamp'] != null) {
            Timestamp timestamp = lastMessageData['timestamp'] as Timestamp;
            _chatTimestamps[chatId] = timestamp;
            chatsWithTimestamps.add(MapEntry(chatDoc, timestamp));
          } else {
            chatsWithTimestamps.add(MapEntry(chatDoc, Timestamp(0, 0)));
          }
        } else {
          chatsWithTimestamps.add(MapEntry(chatDoc, Timestamp(0, 0)));
        }
      } catch (e) {
        print("Error fetching messages for chat $chatId: $e");
        chatsWithTimestamps.add(MapEntry(chatDoc, Timestamp(0, 0)));
      }
    }

    chatsWithTimestamps.sort((a, b) => b.value.compareTo(a.value));
    return chatsWithTimestamps;
  }

  // Filter Chats by Search Query
  Future<List<MapEntry<DocumentSnapshot, Timestamp>>> _filterChatsBySearchQuery(
      List<MapEntry<DocumentSnapshot, Timestamp>> chats, String query) async {
    List<MapEntry<DocumentSnapshot, Timestamp>> filteredChats = [];
    String lowercaseQuery = query.toLowerCase();

    for (var chatEntry in chats) {
      var chatDoc = chatEntry.key;
      var chatData = chatDoc.data() as Map<String, dynamic>?;

      if (chatData == null || chatData['participants'] == null) continue;

      List<dynamic> participants = chatData['participants'];
      String? otherUserId = participants.firstWhere(
            (id) => id != currentUser?.uid && id != null,
        orElse: () => null,
      );

      if (otherUserId == null) continue;

      Map<String, dynamic> userData = await _getUserData(otherUserId);
      String userName = (userData['name'] ?? 'Unknown User').toLowerCase();

      if (userName.contains(lowercaseQuery)) {
        filteredChats.add(chatEntry);
        continue;
      }

      String chatId = chatDoc.id;
      try {
        QuerySnapshot messagesQuery = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('type', isEqualTo: 'text')
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        for (var messageDoc in messagesQuery.docs) {
          var messageData = messageDoc.data() as Map<String, dynamic>;
          String? content = messageData['content'] as String?;

          if (content != null && content.toLowerCase().contains(lowercaseQuery)) {
            filteredChats.add(chatEntry);
            break;
          }
        }
      } catch (e) {
        print("Error searching messages for chat $chatId: $e");
      }
    }

    return filteredChats;
  }
}

// New Message Screen (Full Screen)
class NewMessageScreen extends StatefulWidget {
  @override
  _NewMessageScreenState createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController searchController = TextEditingController();
  final ValueNotifier<List<Map<String, dynamic>>> searchResults = ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<bool> isSearching = ValueNotifier<bool>(false);
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      final value = searchController.text.trim();
      if (value.length >= 2) {
        isSearching.value = true;
        _searchUsers(value).then((results) {
          searchResults.value = results;
          isSearching.value = false;
        });
      } else {
        searchResults.value = [];
        isSearching.value = false;
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchResults.dispose();
    isSearching.dispose();
    super.dispose();
  }

  // Normalize names for consistency
  String _normalizeName(String name) {
    return name.trim().split(' ').map((word) =>
    word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : ''
    ).join(' ').trim();
  }

  // Validate image URL
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    if (url.contains('images.app.goo.gl') ||
        url.contains('google.com/images') ||
        url.contains('gstatic.com/images')) {
      return false;
    }
    bool isValidUrl = url.startsWith('http://') || url.startsWith('https://');
    if (isValidUrl) {
      String lowercaseUrl = url.toLowerCase();
      bool hasImageExtension = lowercaseUrl.endsWith('.jpg') ||
          lowercaseUrl.endsWith('.jpeg') ||
          lowercaseUrl.endsWith('.png') ||
          lowercaseUrl.endsWith('.gif') ||
          lowercaseUrl.endsWith('.webp');
      return hasImageExtension ||
          lowercaseUrl.contains('firebasestorage.googleapis.com') ||
          lowercaseUrl.contains('storage.googleapis.com');
    }
    return false;
  }

  // Search users by name with enhanced deduplication
  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    if (query.isEmpty || currentUser == null) return [];

    final String lowercaseQuery = query.toLowerCase();
    Map<String, Map<String, dynamic>> uniqueUsers = {};

    try {
      // Query users collection
      QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(50) // Limit for efficiency
          .get();

      for (var doc in usersSnapshot.docs) {
        if (doc.id == currentUser!.uid) continue; // Exclude current user

        var data = doc.data() as Map<String, dynamic>;
        String name = _normalizeName(data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'] ??
            data['username'] ??
            '');

        // Prefer existing data if already in uniqueUsers
        if (uniqueUsers.containsKey(doc.id)) {
          // Update only if the new name is more complete (e.g., longer)
          if (name.length > uniqueUsers[doc.id]!['name'].length) {
            uniqueUsers[doc.id]!['name'] = name;
            uniqueUsers[doc.id]!['photoURL'] = data['imageUrl'] ??
                data['photoURL'] ??
                data['profilePic'] ??
                data['avatar'];
          }
        } else if (name.toLowerCase().contains(lowercaseQuery)) {
          uniqueUsers[doc.id] = {
            'id': doc.id,
            'name': name.isNotEmpty ? name : 'Unknown User',
            'photoURL': data['imageUrl'] ??
                data['photoURL'] ??
                data['profilePic'] ??
                data['avatar'],
          };
        }
      }

      // Query studentprofile collection as fallback, but avoid duplicates
      QuerySnapshot studentSnapshot = await FirebaseFirestore.instance
          .collection('studentprofile')
          .limit(50)
          .get();

      for (var doc in studentSnapshot.docs) {
        if (doc.id == currentUser!.uid) continue; // Exclude current user

        var data = doc.data() as Map<String, dynamic>;
        String name = _normalizeName(data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'] ??
            data['username'] ??
            '');

        // Prefer existing data if already in uniqueUsers
        if (uniqueUsers.containsKey(doc.id)) {
          // Update only if the new name is more complete (e.g., longer)
          if (name.length > uniqueUsers[doc.id]!['name'].length) {
            uniqueUsers[doc.id]!['name'] = name;
            uniqueUsers[doc.id]!['photoURL'] = data['imageUrl'] ??
                data['photoURL'] ??
                data['profilePic'] ??
                data['avatar'];
          }
        } else if (name.toLowerCase().contains(lowercaseQuery)) {
          uniqueUsers[doc.id] = {
            'id': doc.id,
            'name': name.isNotEmpty ? name : 'Unknown User',
            'photoURL': data['imageUrl'] ??
                data['photoURL'] ??
                data['profilePic'] ??
                data['avatar'],
          };
        }
      }
    } catch (e) {
      print('Error searching users: $e');
    }

    // Convert map to list and sort by name
    List<Map<String, dynamic>> results = uniqueUsers.values.toList();
    results.sort((a, b) => a['name'].compareTo(b['name']));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: searchController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              icon: Icon(Icons.search, color: Colors.white70),
            ),
            autofocus: true,
          ),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: isSearching,
        builder: (context, searching, _) {
          if (searching) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Searching...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          } else {
            return ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: searchResults,
              builder: (context, results, _) {
                if (searchController.text.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 48,
                          color: AppColors.primaryBlue.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Type to search for users',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No users found for "${searchController.text}"',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final user = results[index];
                      final String userId = user['id'];
                      final String userName = user['name'];
                      final String? photoURL = user['photoURL'];
                      final bool hasValidImage = _isValidImageUrl(photoURL);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                          backgroundImage: hasValidImage ? NetworkImage(photoURL!) : null,
                          child: !hasValidImage
                              ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                              : null,
                        ),
                        title: Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                otherUserId: userId,
                                otherUserName: userName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }
              },
            );
          }
        },
      ),
    );
  }
}

// Create a floating action button for composing new messages
class NewMessageButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.primaryBlue,
      child: Icon(
        Icons.edit,
        color: Colors.white,
      ),
      onPressed: () {
        // Navigate to the new message screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewMessageScreen(),
          ),
        );
      },
    );
  }
}

// Custom AppColors class that matches your ChatScreen colors
class AppColors {
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color veryLightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color accentBlue = Color(0xFF29B6F6);

  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color shadowColor = Color(0xFF000000);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
}