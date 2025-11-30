import 'package:flutter/material.dart';

class TopMenuBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const TopMenuBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: Colors.blueGrey,
      actions: [
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // TODO: Admin menu or user options
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
