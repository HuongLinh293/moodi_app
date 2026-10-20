import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/garden_layout.dart';
import '../models/emotion.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/storage_repository.dart';

enum EntrySyncStatus { pending, synced, failed, sessionOnly }

class MindraState extends ChangeNotifier {
  // Repositories
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final PostRepository _postRepository;
  final FriendRepository _friendRepository;
  final GroupRepository _groupRepository;
  final ChatRepository _chatRepository;
  final StorageRepository _storageRepository;

  // Auth State
  AuthUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;

  // User Data
  UserProfile? _userProfile;
  List<UserProfile> _searchResults = [];

  // Posts
  List<Post> _posts = [];
  PostsPage? _currentPostsPage;
  int _currentPostsPage_num = 1;
  int _currentPostsLimit = 10;

  // Friends
  List<Friend> _friends = [];
  List<FriendRequest> _friendRequests = [];
  List<UserProfile> _friendSuggestions = [];

  // Groups
  List<Group> _groups = [];
  Group? _currentGroup;
  List<GroupMember> _currentGroupMembers = [];

  // Chat
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  List<Message> _currentMessages = [];

  // UI State
  int _currentTab = 0;
  bool _isLoading = false;
  String? _error;

  // Getters
  AuthUser? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.id;
  bool get isAuthenticated => _currentUser != null;

  UserProfile? get userProfile => _userProfile;
  List<Post> get posts => List.unmodifiable(_posts);
  List<Friend> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get friendRequests => List.unmodifiable(_friendRequests);
  List<UserProfile> get friendSuggestions =>
      List.unmodifiable(_friendSuggestions);
  List<Group> get groups => List.unmodifiable(_groups);
  List<Conversation> get conversations =>
      List.unmodifiable(_conversations);
  List<Message> get currentMessages => List.unmodifiable(_currentMessages);

  int get currentTab => _currentTab;
  bool get isLoading => _isLoading;
  String? get error => _error;

  MindraState({
    AuthRepository? authRepository,
    UserRepository? userRepository,
    PostRepository? postRepository,
    FriendRepository? friendRepository,
    GroupRepository? groupRepository,
    ChatRepository? chatRepository,
    StorageRepository? storageRepository,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _postRepository = postRepository ?? PostRepository(),
        _friendRepository = friendRepository ?? FriendRepository(),
        _groupRepository = groupRepository ?? GroupRepository(),
        _chatRepository = chatRepository ?? ChatRepository(),
        _storageRepository = storageRepository ?? StorageRepository() {
    _initialize();
  }

  void _initialize() {
    _currentUser = _authRepository.currentUser;
    _accessToken = _authRepository.currentUserId;
    if (_currentUser != null) {
      _loadUserProfile();
      _loadPosts();
      _loadFriends();
      _loadGroups();
      _loadConversations();
    }
  }

  // ========== AUTH METHODS ==========
  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final response =
          await _authRepository.signInWithEmailPassword(email, password);
      if (response != null) {
        _currentUser = response.user;
        _accessToken = response.accessToken;
        _refreshToken = response.refreshToken;
        _clearError();
        _loadUserProfile();
        _loadPosts();
        _loadFriends();
        _loadGroups();
        _loadConversations();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String email, String password, String displayName) async {
    _setLoading(true);
    try {
      final response = await _authRepository.registerWithEmailPassword(
        email,
        password,
      );
      if (response != null) {
        _currentUser = response.user;
        _accessToken = response.accessToken;
        _refreshToken = response.refreshToken;
        _clearError();
        _loadUserProfile();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _userProfile = null;
    _posts.clear();
    _friends.clear();
    _friendRequests.clear();
    _groups.clear();
    _conversations.clear();
    _currentMessages.clear();
    notifyListeners();
  }

  // ========== USER METHODS ==========
  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;
    try {
      final profile = await _userRepository.getUserById(_currentUser!.id);
      if (profile != null) {
        _userProfile = profile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> updateProfile(String displayName, String bio) async {
    if (_currentUser == null) return;
    _setLoading(true);
    try {
      final updated = await _userRepository.updateProfile(
        userId: _currentUser!.id,
        displayName: displayName,
        bio: bio,
      );
      if (updated != null) {
        _userProfile = updated;
        _clearError();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateAvatar(String avatarUrl) async {
    if (_currentUser == null) return;
    try {
      final updated = await _userRepository.updateAvatar(
        _currentUser!.id,
        avatarUrl,
      );
      if (updated != null) {
        _userProfile = updated;
      }
    } catch (e) {
      debugPrint('Error updating avatar: $e');
    }
  }

  Future<void> searchUsers(String query) async {
    try {
      _searchResults = await _userRepository.searchUsers(query);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  // ========== POST METHODS ==========
  Future<void> _loadPosts() async {
    try {
      final page = await _postRepository.getPosts(page: 1, limit: 10);
      if (page != null) {
        _posts = page.data;
        _currentPostsPage = page;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
    }
  }

  Future<void> createPost(String content, List<String>? imageUrls) async {
    _setLoading(true);
    try {
      final post =
          await _postRepository.createPost(content: content, imageUrls: imageUrls);
      if (post != null) {
        _posts.insert(0, post);
        _clearError();
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updatePost(
    String postId,
    String content,
    List<String>? imageUrls,
  ) async {
    try {
      final updated = await _postRepository.updatePost(
        postId: postId,
        content: content,
        imageUrls: imageUrls,
      );
      if (updated != null) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _posts[index] = updated;
          notifyListeners();
        }
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      final success = await _postRepository.deletePost(postId);
      if (success) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> likePost(String postId) async {
    try {
      final success = await _postRepository.likePost(postId);
      if (success) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error liking post: $e');
    }
  }

  Future<void> unlikePost(String postId) async {
    try {
      final success = await _postRepository.unlikePost(postId);
      if (success) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error unliking post: $e');
    }
  }

  // ========== FRIEND METHODS ==========
  Future<void> _loadFriends() async {
    try {
      final page = await _friendRepository.getFriends(page: 1, limit: 10);
      if (page != null) {
        _friends = page.data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      final page = await _friendRepository.getFriendRequests(page: 1, limit: 10);
      if (page != null) {
        _friendRequests = page.data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading friend requests: $e');
    }
  }

  Future<void> sendFriendRequest(String friendId) async {
    try {
      final success = await _friendRepository.sendFriendRequest(friendId);
      if (success) {
        _clearError();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final success = await _friendRepository.acceptFriendRequest(requestId);
      if (success) {
        _friendRequests.removeWhere((r) => r.id == requestId);
        _loadFriends();
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    try {
      final success = await _friendRepository.rejectFriendRequest(requestId);
      if (success) {
        _friendRequests.removeWhere((r) => r.id == requestId);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> removeFriend(String friendId) async {
    try {
      final success = await _friendRepository.removeFriend(friendId);
      if (success) {
        _friends.removeWhere((f) => f.friendId == friendId);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> loadFriendSuggestions() async {
    try {
      _friendSuggestions = await _friendRepository.getFriendSuggestions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
    }
  }

  // ========== GROUP METHODS ==========
  Future<void> _loadGroups() async {
    try {
      final page = await _groupRepository.getGroups(page: 1, limit: 10);
      if (page != null) {
        _groups = page.data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
    }
  }

  Future<void> createGroup(
    String name,
    String? description,
    String? image,
  ) async {
    _setLoading(true);
    try {
      final group =
          await _groupRepository.createGroup(name: name, description: description, image: image);
      if (group != null) {
        _groups.insert(0, group);
        _clearError();
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectGroup(String groupId) async {
    try {
      final group = await _groupRepository.getGroupById(groupId);
      if (group != null) {
        _currentGroup = group;
        _loadGroupMembers(groupId);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _loadGroupMembers(String groupId) async {
    try {
      final page = await _groupRepository.getGroupMembers(groupId, page: 1, limit: 20);
      if (page != null) {
        _currentGroupMembers = page.data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading group members: $e');
    }
  }

  Future<void> addGroupMember(String groupId, String userId) async {
    try {
      final success = await _groupRepository.addMember(groupId, userId);
      if (success) {
        _loadGroupMembers(groupId);
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    try {
      final success = await _groupRepository.removeMember(groupId, userId);
      if (success) {
        _currentGroupMembers.removeWhere((m) => m.userId == userId);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> leaveGroup(String groupId) async {
    try {
      final success = await _groupRepository.leaveGroup(groupId);
      if (success) {
        _groups.removeWhere((g) => g.id == groupId);
        _currentGroup = null;
        _currentGroupMembers.clear();
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ========== CHAT METHODS ==========
  Future<void> _loadConversations() async {
    try {
      final page = await _chatRepository.getConversations(page: 1, limit: 20);
      if (page != null) {
        _conversations = page.data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    }
  }

  Future<void> selectConversation(String conversationId) async {
    try {
      final conversation = await _chatRepository.getConversationById(conversationId);
      if (conversation != null) {
        _currentConversation = conversation;
        _loadMessages(conversationId);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _loadMessages(String conversationId) async {
    try {
      final page = await _chatRepository.getMessages(conversationId, page: 1, limit: 50);
      if (page != null) {
        _currentMessages = page.data.reversed.toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> createConversation(
    String type,
    List<String> participantIds,
    String? name,
  ) async {
    _setLoading(true);
    try {
      final conversation = await _chatRepository.createConversation(
        type: type,
        participantIds: participantIds,
        name: name,
      );
      if (conversation != null) {
        _conversations.insert(0, conversation);
        _clearError();
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage(String conversationId, String content, List<String>? imageUrls) async {
    try {
      final message = await _chatRepository.sendMessage(
        conversationId: conversationId,
        content: content,
        imageUrls: imageUrls,
      );
      if (message != null) {
        _currentMessages.add(message);
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ========== STORAGE METHODS ==========
  Future<StorageFile?> uploadFile({
    required String filename,
    required String fileContent,
    String? mimeType,
    String accessType = 'private',
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    try {
      return await _storageRepository.uploadFile(
        filename: filename,
        fileContent: fileContent,
        mimeType: mimeType,
        accessType: accessType,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
      );
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // ========== UI STATE METHODS ==========
  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
