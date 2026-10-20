import 'dart:math';

import 'community_repository.dart';

/// In-memory transport for demo, testing, and offline fallback when Cloud Functions
/// is not deployed or unreachable. All data stays local to the current session.
class InMemoryCommunityTransport {
  InMemoryCommunityTransport({
    required String currentUid,
    String currentName = 'Linh',
  }) {
    _myUid = currentUid.isNotEmpty ? currentUid : 'demo_linh';
    _initSeedData(currentName);
  }

  late final String _myUid;
  String get uid => _myUid;

  // Stored state
  final Map<String, Json> _profiles = {};
  final List<Json> _posts = [];
  final Map<String, List<Json>> _comments = {};
  final List<Json> _groups = [];
  final Map<String, Json> _connections = {}; // key: pairId
  final Map<String, List<Json>> _messages = {}; // key: pairId
  final List<Json> _reports = [];
  final Map<String, String> _images = {}; // key: id, value: base64

  static const String placeholderPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  String _pairId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}__${list[1]}';
  }

  void _initSeedData(String currentName) {
    final now = DateTime.now();

    // Profiles
    _profiles[_myUid] = {
      'id': _myUid,
      'name': currentName.isNotEmpty ? currentName : 'Linh',
      'bio': 'Tìm kiếm sự cân bằng và bình yên.',
      'handle': 'linh2026mood',
      'suspended': false,
    };

    _profiles['user_minh'] = {
      'id': 'user_minh',
      'name': 'Minh',
      'bio': 'Thực tập sinh thiết kế. Đang học cách sống chậm lại.',
      'handle': 'minh2026mood',
      'suspended': false,
    };

    _profiles['user_an'] = {
      'id': 'user_an',
      'name': 'An Nhiên',
      'bio': 'Yêu cây cỏ và những ngày mưa.',
      'handle': 'annhienmoodi',
      'suspended': false,
    };

    _profiles['user_hoang'] = {
      'id': 'user_hoang',
      'name': 'Hoàng',
      'bio': 'Kỹ sư phần mềm. Học cách thấu hiểu cảm xúc.',
      'handle': 'hoangdev2026',
      'suspended': false,
    };

    // Public Posts
    final post1Id = 'post_seed_1';
    _posts.add({
      'id': post1Id,
      'space': 'public',
      'author': 'user_minh',
      'authorName': 'Minh',
      'text': 'Hôm nay mình đã hoàn thành bài thuyết trình đồ án sau cả tuần mất ngủ. Vẫn còn run một chút, nhưng thật vui vì đã dám thử và không bỏ cuộc.',
      'mood': 'Vui vẻ',
      'intent': 'Chia sẻ chuyện vui',
      'imagePath': '',
      'likes': 4,
      'liked': false,
      'commentsOpen': true,
      'createdAt': now
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch,
    });

    _comments[post1Id] = [
      {
        'id': 'c1_1',
        'author': 'user_an',
        'authorName': 'An Nhiên',
        'text': 'Chúc mừng bạn nhé! Vượt qua được nỗi sợ là bước tiến lớn rồi.',
        'createdAt': now
            .subtract(const Duration(hours: 1, minutes: 40))
            .millisecondsSinceEpoch,
        'canDelete': false,
      },
      {
        'id': 'c1_2',
        'author': 'user_hoang',
        'authorName': 'Hoàng',
        'text': 'Tuyệt vời quá! Nghỉ ngơi thật tốt tối nay nhé bạn.',
        'createdAt': now
            .subtract(const Duration(hours: 1, minutes: 15))
            .millisecondsSinceEpoch,
        'canDelete': false,
      },
    ];

    final post2Id = 'post_seed_2';
    _posts.add({
      'id': post2Id,
      'space': 'public',
      'author': 'user_an',
      'authorName': 'An Nhiên',
      'text': 'Có những buổi chiều chỉ muốn ngồi yên một góc, ngắm cây lá và nghe tiếng mưa rơi. Không buồn, cũng không quá vui, chỉ là một khoảng lặng cần thiết sau một tuần bận rộn.',
      'mood': 'Bình yên',
      'intent': 'Chỉ muốn được lắng nghe',
      'imagePath': '',
      'likes': 7,
      'liked': false,
      'commentsOpen': true,
      'createdAt': now
          .subtract(const Duration(hours: 6))
          .millisecondsSinceEpoch,
    });

    _comments[post2Id] = [
      {
        'id': 'c2_1',
        'author': 'user_minh',
        'authorName': 'Minh',
        'text': 'Đôi khi khoảng lặng như vậy quý giá hơn bất cứ điều gì.',
        'createdAt': now
            .subtract(const Duration(hours: 5))
            .millisecondsSinceEpoch,
        'canDelete': false,
      },
    ];

    final post3Id = 'post_seed_3';
    _posts.add({
      'id': post3Id,
      'space': 'public',
      'author': 'user_hoang',
      'authorName': 'Hoàng',
      'text': 'Dạo này công việc dồn dập khiến mình dễ nổi nóng với những chuyện nhỏ nhặt. Có ai từng rơi vào trạng thái này và tìm được cách xoa dịu bản thân chưa ạ?',
      'mood': 'Áp lực',
      'intent': 'Có ai từng trải qua không?',
      'imagePath': '',
      'likes': 5,
      'liked': false,
      'commentsOpen': true,
      'createdAt': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    });

    _comments[post3Id] = [
      {
        'id': 'c3_1',
        'author': 'user_an',
        'authorName': 'An Nhiên',
        'text': 'Mình hay thử bài tập thở 4-4-4-4 trong app, dừng lại 2 phút trước khi phản ứng.',
        'createdAt': now
            .subtract(const Duration(hours: 20))
            .millisecondsSinceEpoch,
        'canDelete': false,
      },
    ];

    // Groups
    _groups.add({
      'id': 'group_family',
      'name': 'Góc nhỏ Gia đình',
      'description': 'Nơi chia sẻ những khoảnh khắc đời thường bình dị.',
      'owner': _myUid,
      'members': [_myUid, 'user_minh', 'user_an'],
      'invited': <String>[],
      'createdAt': now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
    });

    _groups.add({
      'id': 'group_friends',
      'name': 'Hội bạn thân Moodi',
      'description': 'Cùng nhau lắng nghe và đồng hành mỗi ngày.',
      'owner': 'user_hoang',
      'members': ['user_hoang', 'user_an'],
      'invited': [_myUid],
      'createdAt': now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
    });

    // Connections
    final pairMinh = _pairId(_myUid, 'user_minh');
    _connections[pairMinh] = {
      'status': 'accepted',
      'requestedBy': 'user_minh',
      'blockedBy': <String>[],
      'hasMessages': true,
    };

    final pairAn = _pairId(_myUid, 'user_an');
    _connections[pairAn] = {
      'status': 'accepted',
      'requestedBy': _myUid,
      'blockedBy': <String>[],
      'hasMessages': false,
    };

    final pairHoang = _pairId(_myUid, 'user_hoang');
    _connections[pairHoang] = {
      'status': 'pending',
      'requestedBy': 'user_hoang',
      'blockedBy': <String>[],
      'hasMessages': false,
    };

    // Chat messages with Minh
    _messages[pairMinh] = [
      {
        'id': 'msg_1',
        'sender': 'user_minh',
        'text': 'Chào bạn! Mình vừa đọc chia sẻ của bạn trên Góc sẻ chia, thấy đồng cảm lắm.',
        'imagePath': '',
        'removed': false,
        'createdAt': now
            .subtract(const Duration(days: 1, hours: 2))
            .millisecondsSinceEpoch,
      },
      {
        'id': 'msg_2',
        'sender': _myUid,
        'text': 'Cảm ơn Minh nhiều nhé! Nhờ có sự lắng nghe của mọi người mà mình thấy nhẹ lòng hơn hẳn.',
        'imagePath': '',
        'removed': false,
        'createdAt': now
            .subtract(const Duration(days: 1, hours: 1))
            .millisecondsSinceEpoch,
      },
      {
        'id': 'msg_3',
        'sender': 'user_minh',
        'text': 'Bất cứ khi nào cần người lắng nghe, bạn cứ nhắn nhé.',
        'imagePath': '',
        'removed': false,
        'createdAt': now
            .subtract(const Duration(hours: 18))
            .millisecondsSinceEpoch,
      },
    ];

    // Seed reports for admin moderation
    _reports.add({
      'id': 'rep_1',
      'reason': 'Nội dung gây căng thẳng hoặc ngôn từ kích động',
      'evidence':
          'Bài viết có lời lẽ chưa phù hợp với không gian chia sẻ chung.',
      'status': 'open',
      'createdAt': now
          .subtract(const Duration(hours: 4))
          .millisecondsSinceEpoch,
    });
  }

  Future<Json> handle(Json payload) async {
    final action = payload['action'] as String;

    switch (action) {
      case 'bootstrap':
        final me = _profiles[_myUid];
        final pending = _connections.values
            .where(
              (c) => c['status'] == 'pending' && c['requestedBy'] != _myUid,
            )
            .length;
        final unread = 1; // 1 unread message from Minh
        return {'me': me, 'admin': true, 'pending': pending, 'unread': unread};

      case 'saveProfile':
        final name = (payload['name'] as String? ?? '').trim();
        final bio = (payload['bio'] as String? ?? '').trim();
        final handle =
            _profiles[_myUid]?['handle'] ??
            List.generate(
              12,
              (_) => Random().nextInt(16).toRadixString(16),
            ).join();
        _profiles[_myUid] = {
          'id': _myUid,
          'name': name.isNotEmpty ? name : 'Bạn',
          'bio': bio,
          'handle': handle,
          'suspended': false,
        };
        return {'id': _myUid};

      case 'profile':
        final target = payload['target'] as String;
        final profile =
            _profiles[target] ??
            {
              'id': target,
              'name': 'Người dùng',
              'bio': '',
              'handle': 'user_$target',
            };
        final pId = _pairId(_myUid, target);
        final rel =
            _connections[pId] ??
            {
              'status': 'none',
              'requestedBy': '',
              'blockedBy': <String>[],
              'hasMessages': false,
            };
        return {'profile': profile, 'relation': rel};

      case 'search':
        final handle = (payload['handle'] as String? ?? '')
            .trim()
            .toLowerCase();
        for (final p in _profiles.values) {
          if ((p['handle'] as String? ?? '').toLowerCase() == handle) {
            return {'profile': p};
          }
        }
        return {'profile': null};

      case 'feed':
        final space = payload['space'] as String? ?? 'public';
        final author = payload['author'] as String?;
        final mood = payload['mood'] as String?;
        final items =
            _posts.where((p) {
              if (p['space'] != space) return false;
              if (author != null && p['author'] != author) return false;
              if (mood != null && mood.isNotEmpty && p['mood'] != mood) {
                return false;
              }
              return true;
            }).toList()..sort(
              (a, b) =>
                  (b['createdAt'] as num).compareTo(a['createdAt'] as num),
            );
        return {'items': items, 'cursor': null};

      case 'post':
        final postId = payload['postId'] as String;
        final post = _posts.firstWhere(
          (p) => p['id'] == postId,
          orElse: () => {},
        );
        return {'post': post.isNotEmpty ? post : null};

      case 'createPost':
        final space = payload['space'] as String? ?? 'public';
        final text = payload['text'] as String? ?? '';
        final mood = payload['mood'] as String? ?? '';
        final intent = payload['intent'] as String? ?? '';
        final image = payload['image'] as String?;
        final newId = 'post_${DateTime.now().millisecondsSinceEpoch}';
        var imgPath = '';
        if (image != null && image.isNotEmpty) {
          imgPath = 'posts/$newId.jpg';
          _images[imgPath] = image;
        }
        final me = _profiles[_myUid];
        final post = {
          'id': newId,
          'space': space,
          'author': _myUid,
          'authorName': me?['name'] ?? 'Tôi',
          'text': text,
          'mood': mood,
          'intent': intent,
          'imagePath': imgPath,
          'likes': 0,
          'liked': false,
          'commentsOpen': true,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        };
        _posts.insert(0, post);
        return {'id': newId};

      case 'deletePost':
        final postId = payload['postId'] as String;
        _posts.removeWhere((p) => p['id'] == postId);
        return {'deleted': true};

      case 'toggleComments':
        final postId = payload['postId'] as String;
        final enabled = payload['enabled'] == true;
        for (final p in _posts) {
          if (p['id'] == postId) {
            p['commentsOpen'] = enabled;
            break;
          }
        }
        return {'ok': true};

      case 'react':
        final postId = payload['postId'] as String;
        final enabled = payload['enabled'] == true;
        for (final p in _posts) {
          if (p['id'] == postId) {
            final cur = p['likes'] as int? ?? 0;
            p['liked'] = enabled;
            p['likes'] = enabled ? cur + 1 : (cur > 0 ? cur - 1 : 0);
            break;
          }
        }
        return {'ok': true};

      case 'comments':
        final postId = payload['postId'] as String;
        final list = _comments[postId] ?? [];
        return {'items': list};

      case 'comment':
        final postId = payload['postId'] as String;
        final text = payload['text'] as String? ?? '';
        final cId = 'comment_${DateTime.now().millisecondsSinceEpoch}';
        final me = _profiles[_myUid];
        final item = {
          'id': cId,
          'author': _myUid,
          'authorName': me?['name'] ?? 'Tôi',
          'text': text,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'canDelete': true,
        };
        _comments.putIfAbsent(postId, () => []).add(item);
        return {'id': cId};

      case 'deleteComment':
        final postId = payload['postId'] as String;
        final commentId = payload['commentId'] as String;
        _comments[postId]?.removeWhere((c) => c['id'] == commentId);
        return {'deleted': true};

      case 'groups':
        final myGroups = _groups.where((g) {
          final members = (g['members'] as List? ?? []);
          return members.contains(_myUid);
        }).toList();
        final myInvites = _groups.where((g) {
          final invited = (g['invited'] as List? ?? []);
          return invited.contains(_myUid);
        }).toList();
        return {'items': myGroups, 'invites': myInvites};

      case 'createGroup':
        final name = payload['name'] as String? ?? 'Nhóm mới';
        final description = payload['description'] as String? ?? '';
        final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
        final g = {
          'id': groupId,
          'name': name,
          'description': description,
          'owner': _myUid,
          'members': [_myUid],
          'invited': <String>[],
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        };
        _groups.insert(0, g);
        return {'id': groupId};

      case 'group':
        final space = payload['space'] as String;
        final g = _groups.firstWhere((x) => x['id'] == space, orElse: () => {});
        if (g.isEmpty) throw StateError('Không tìm thấy nhóm.');
        final memberProfiles = (g['members'] as List).map((mId) {
          return _profiles[mId] ?? {'id': mId, 'name': 'Thành viên'};
        }).toList();
        final invitedProfiles = (g['invited'] as List).map((mId) {
          return _profiles[mId] ?? {'id': mId, 'name': 'Được mời'};
        }).toList();
        return {
          'group': g,
          'members': memberProfiles,
          'invited': invitedProfiles,
        };

      case 'invite':
        final space = payload['space'] as String;
        final target = payload['target'] as String;
        for (final g in _groups) {
          if (g['id'] == space) {
            final invited = (g['invited'] as List);
            if (!invited.contains(target)) invited.add(target);
            break;
          }
        }
        return {'ok': true};

      case 'groupAction':
        final space = payload['space'] as String;
        final kind = payload['kind'] as String;
        final target = payload['target'] as String?;
        final g = _groups.firstWhere((x) => x['id'] == space, orElse: () => {});
        if (g.isNotEmpty) {
          final members = g['members'] as List;
          final invited = g['invited'] as List;
          if (kind == 'accept') {
            invited.remove(_myUid);
            if (!members.contains(_myUid)) members.add(_myUid);
          } else if (kind == 'decline') {
            invited.remove(_myUid);
          } else if (kind == 'leave') {
            members.remove(_myUid);
          } else if (kind == 'close') {
            _groups.remove(g);
          } else if (kind == 'remove' && target != null) {
            members.remove(target);
            invited.remove(target);
          } else if (kind == 'transfer' && target != null) {
            g['owner'] = target;
          }
        }
        return {'ok': true};

      case 'connections':
        final items = <Json>[];
        for (final entry in _connections.entries) {
          final pair = entry.key.split('__');
          if (!pair.contains(_myUid)) continue;
          final otherUid = pair[0] == _myUid ? pair[1] : pair[0];
          final profile =
              _profiles[otherUid] ?? {'id': otherUid, 'name': 'Bạn bè'};
          items.add({...entry.value, 'profile': profile});
        }
        return {'items': items};

      case 'friendship':
        final target = payload['target'] as String;
        final kind = payload['kind'] as String;
        final pId = _pairId(_myUid, target);
        final rel = _connections.putIfAbsent(
          pId,
          () => {
            'status': 'none',
            'requestedBy': '',
            'blockedBy': <String>[],
            'hasMessages': false,
          },
        );
        final blocked = rel['blockedBy'] as List;
        if (kind == 'request') {
          rel['status'] = 'pending';
          rel['requestedBy'] = _myUid;
        } else if (kind == 'accept') {
          rel['status'] = 'accepted';
        } else if (kind == 'decline' || kind == 'cancel') {
          rel['status'] = 'none';
          rel['requestedBy'] = '';
        } else if (kind == 'unfriend') {
          rel['status'] = 'none';
        } else if (kind == 'block') {
          if (!blocked.contains(_myUid)) blocked.add(_myUid);
        } else if (kind == 'unblock') {
          blocked.remove(_myUid);
        }
        return {'ok': true};

      case 'messages':
        final target = payload['target'] as String;
        final pId = _pairId(_myUid, target);
        final list = _messages[pId] ?? [];
        final rel =
            _connections[pId] ??
            {
              'status': 'accepted',
              'blockedBy': <String>[],
              'hasMessages': true,
            };
        return {
          'items': list.reversed.toList(),
          'relation': rel,
          'cursor': null,
        };

      case 'sendMessage':
        final target = payload['target'] as String;
        final text = payload['text'] as String? ?? '';
        final image = payload['image'] as String?;
        final pId = _pairId(_myUid, target);
        final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
        var imgPath = '';
        if (image != null && image.isNotEmpty) {
          imgPath = 'messages/$msgId.jpg';
          _images[imgPath] = image;
        }
        final msg = {
          'id': msgId,
          'sender': _myUid,
          'text': text,
          'imagePath': imgPath,
          'removed': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        };
        _messages.putIfAbsent(pId, () => []).add(msg);
        final rel = _connections.putIfAbsent(
          pId,
          () => {
            'status': 'accepted',
            'requestedBy': _myUid,
            'blockedBy': <String>[],
            'hasMessages': true,
          },
        );
        rel['hasMessages'] = true;
        return {'id': msgId};

      case 'image':
        final postId = payload['postId'] as String?;
        final messageId = payload['messageId'] as String?;
        if (postId != null && _images.containsKey('posts/$postId.jpg')) {
          return {'image': _images['posts/$postId.jpg']!};
        }
        if (messageId != null &&
            _images.containsKey('messages/$messageId.jpg')) {
          return {'image': _images['messages/$messageId.jpg']!};
        }
        return {'image': placeholderPng};

      case 'report':
        final reason = payload['reason'] as String? ?? 'Báo cáo vi phạm';
        _reports.add({
          'id': 'rep_${DateTime.now().millisecondsSinceEpoch}',
          'reason': reason,
          'evidence': payload['postId'] != null
              ? 'Bài viết ${payload['postId']}'
              : 'Hồ sơ người dùng',
          'status': 'open',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        return {'reported': true};

      case 'reports':
        return {'items': _reports, 'cursor': null};

      case 'moderate':
        final repId = payload['reportId'] as String;
        for (final r in _reports) {
          if (r['id'] == repId) {
            r['status'] = 'resolved';
            break;
          }
        }
        return {'moderated': true};

      default:
        return {'ok': true};
    }
  }
}
