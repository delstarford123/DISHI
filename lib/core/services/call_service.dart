import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/match/presentation/match_call_view.dart';

/// System-wide DISHI Call Service
/// Handles in-app WebRTC Voice and Video calls across all user roles:
/// Students, Vendors, Fundis, Drivers, and Parents.
/// Signaling runs via Firebase Firestore, working seamlessly on Vercel backend.
class DishiCallService {
  /// Start a voice or video call directly
  static void startCall(
    BuildContext context, {
    required String targetUserId,
    required String targetUserName,
    String? targetUserAvatar,
    required bool isVideo,
  }) {
    HapticFeedback.lightImpact();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF131A2A),
          content: Text('Please log in to make calls', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    if (currentUser.uid == targetUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF131A2A),
          content: Text('You cannot call yourself', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchCallView(
          userName: targetUserName,
          userAvatar: targetUserAvatar ?? '',
          calleeId: targetUserId,
          isVideoCall: isVideo,
          isIncoming: false,
        ),
      ),
    );
  }

  /// Show a beautiful bottom sheet allowing the caller to choose Voice or Video
  static void showCallOptions(
    BuildContext context, {
    required String targetUserId,
    required String targetUserName,
    String? targetUserAvatar,
    String subtitle = 'Free encrypted call over internet',
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF05D5AA),
                    backgroundImage: targetUserAvatar != null && targetUserAvatar.isNotEmpty
                        ? NetworkImage(targetUserAvatar)
                        : null,
                    child: (targetUserAvatar == null || targetUserAvatar.isEmpty)
                        ? const Icon(Icons.person, color: Colors.black87)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          targetUserName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF05D5AA),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.phone, size: 20),
                      label: const Text(
                        'Voice Call',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        startCall(
                          context,
                          targetUserId: targetUserId,
                          targetUserName: targetUserName,
                          targetUserAvatar: targetUserAvatar,
                          isVideo: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.videocam, size: 20),
                      label: const Text(
                        'Video Call',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        startCall(
                          context,
                          targetUserId: targetUserId,
                          targetUserName: targetUserName,
                          targetUserAvatar: targetUserAvatar,
                          isVideo: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
