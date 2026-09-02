import 'package:flutter/material.dart';

/// Git provider target bar with provider toggle and editable project name.
class GitTargetBar extends StatelessWidget {
  const GitTargetBar({
    super.key,
    required this.selectedProvider,
    required this.projectName,
    required this.isEditingName,
    required this.nameController,
    required this.onProviderChanged,
    required this.onEditingNameStart,
    required this.onProjectNameSubmitted,
    required this.onLog,
  });

  final String selectedProvider;
  final String projectName;
  final bool isEditingName;
  final TextEditingController nameController;
  final ValueChanged<String> onProviderChanged;
  final VoidCallback onEditingNameStart;
  final ValueChanged<String> onProjectNameSubmitted;
  final void Function(String msg, String type) onLog;

  @override
  Widget build(BuildContext context) {
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
                    _ProviderBtn(
                      name: 'GitHub',
                      isSelected: selectedProvider == 'GitHub',
                      onTap: () {
                        onProviderChanged('GitHub');
                        onLog('CEO Config: Switched Git provider to GitHub', 'ceo');
                      },
                    ),
                    _ProviderBtn(
                      name: 'GitLab',
                      isSelected: selectedProvider == 'GitLab',
                      onTap: () {
                        onProviderChanged('GitLab');
                        onLog('CEO Config: Switched Git provider to GitLab', 'ceo');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: const Color(0xFF3E484F)),
              const SizedBox(width: 16),

              // Project Name Editor
              if (isEditingName)
                SizedBox(
                  width: 260,
                  height: 32,
                  child: TextField(
                    controller: nameController,
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
                    onSubmitted: onProjectNameSubmitted,
                  ),
                )
              else
                InkWell(
                  onTap: onEditingNameStart,
                  child: Row(
                    children: [
                      SelectableText(
                        projectName,
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
              const SelectableText(
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
}

class _ProviderBtn extends StatelessWidget {
  const _ProviderBtn({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF273647) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: SelectableText(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? const Color(0xFFD4E4FA) : const Color(0xFFBDC8D1),
          ),
        ),
      ),
    );
  }
}
