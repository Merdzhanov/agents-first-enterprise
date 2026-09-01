import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Gittargetbar extends StatelessWidget {
  final _DashboardScreenState state;
  
  const Gittargetbar({super.key, required this.state});

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(150),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Segmented Toggle
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3E484F)),
                ),
                child: Row(
                  children: [
                    state._buildProviderBtn('GitHub'),
                    state._buildProviderBtn('GitLab'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: const Color(0xFF3E484F)),
              const SizedBox(width: 16),

              // Project Name Editor
              if (state._isEditingName)
                SizedBox(
                  width: 260,
                  height: 32,
                  child: TextField(
                    controller: state._nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF7BD0FF),
                    ),
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (val) {
                      setState(() {
                        state._projectName = val.trim();
                        state._isEditingName = false;
                      });
                    },
                  ),
                )
              else
                InkWell(
                  onTap: () {
                    setState(() {
                      state._isEditingName = true;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        state._projectName,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF7BD0FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 14, color: Color(0xFFBDC8D1)),
                    ],
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sync Active',
                style: TextStyle(
                  color: Color(0xFFBDC8D1),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  
}
