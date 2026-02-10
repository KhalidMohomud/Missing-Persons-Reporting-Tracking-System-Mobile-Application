import 'package:flutter/material.dart';
import '../session/user_session.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          /// Profile Picture + Name
          Expanded(
            child: ValueListenableBuilder<UserInfo?>(
              valueListenable: UserSession.current,
              builder: (context, user, _) {
                final name = user?.name ?? 'Guest';
                final photoUrl = user?.photoUrl ?? '';
                final hasPhoto =
                    photoUrl.isNotEmpty && photoUrl.startsWith('http');

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                      child: hasPhoto
                          ? null
                          : const Icon(Icons.person, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          /// Notification Bell
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
