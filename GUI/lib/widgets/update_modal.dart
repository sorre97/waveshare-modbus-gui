import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme.dart';

/// Shows the update modal and returns when dismissed.
Future<void> showUpdateModal(
  BuildContext context,
  UpdateService service,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateModal(service: service),
  );
}

class _UpdateModal extends StatefulWidget {
  final UpdateService service;
  const _UpdateModal({required this.service});

  @override
  State<_UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends State<_UpdateModal> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);

    // If we open the modal while still in 'idle' or 'upToDate' state,
    // kick off a fresh check.
    final s = widget.service.status;
    if (s == UpdateStatus.idle ||
        s == UpdateStatus.upToDate ||
        s == UpdateStatus.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.service.checkForUpdate();
      });
    }
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() => setState(() {});

  void _startDownload() => widget.service.downloadUpdate();

  void _restart() {
    Navigator.of(context).pop();
    widget.service.applyAndRestart();
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final status = svc.status;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1020),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kNeonGlowBg,
                    border: Border.all(color: kNeonGlowBorder),
                  ),
                  child: Icon(
                    _headerIcon(status),
                    color: kPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headerTitle(status),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                          fontFamily: 'SpaceGrotesk',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current version: ${svc.currentVersion.isEmpty ? '—' : svc.currentVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button — only when not actively downloading
                if (status != UpdateStatus.downloading)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _dismiss,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: kOnSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 24),

            // ── Body ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: _buildBody(status, svc),
            ),

            const SizedBox(height: 28),

            // ── Actions ───────────────────────────────────────────────
            _buildActions(status, svc),
          ],
        ),
      ),
    );
  }

  // ── Body variants ─────────────────────────────────────────────────────────

  Widget _buildBody(UpdateStatus status, UpdateService svc) {
    switch (status) {
      case UpdateStatus.checking:
        return _CenteredStatus(
          icon: Icons.cloud_upload_rounded,
          message: 'Checking for updates...',
          subtitle: 'Querying GitHub Releases',
          spinning: true,
        );

      case UpdateStatus.upToDate:
        return _CenteredStatus(
          icon: Icons.check_circle_outline_rounded,
          message: 'You\'re up to date',
          subtitle: 'Version ${svc.currentVersion} is the latest release.',
          iconColor: kPrimary,
        );

      case UpdateStatus.available:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VersionBadge(
              current: svc.currentVersion,
              next: svc.updateInfo?.version ?? '',
            ),
            const SizedBox(height: 16),
            const Text(
              'RELEASE NOTES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: kOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  svc.updateInfo?.body.isNotEmpty == true
                      ? svc.updateInfo!.body
                      : 'No release notes provided.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: kOnSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        );

      case UpdateStatus.downloading:
        final pct = (svc.downloadProgress * 100).toInt();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Downloading update...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kOnSurface,
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                    fontFamily: 'SpaceGrotesk',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: svc.downloadProgress,
                minHeight: 6,
                backgroundColor: kSurfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              svc.updateInfo != null
                  ? 'Downloading ${svc.updateInfo!.tagName}...'
                  : 'Please wait',
              style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant),
            ),
          ],
        );

      case UpdateStatus.readyToRestart:
        return _CenteredStatus(
          icon: Icons.check_circle_rounded,
          message: 'Download complete!',
          subtitle:
              'Version ${svc.updateInfo?.version ?? ''} is ready. Restart the app to apply the update.',
          iconColor: kPrimary,
        );

      case UpdateStatus.error:
        return _CenteredStatus(
          icon: Icons.error_outline_rounded,
          message: 'Update check failed',
          subtitle: svc.errorMessage,
          iconColor: kError,
        );

      case UpdateStatus.idle:
        return _CenteredStatus(
          icon: Icons.cloud_upload_rounded,
          message: 'Software Update',
          subtitle: 'Initializing...',
          spinning: true,
        );
    }
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActions(UpdateStatus status, UpdateService svc) {
    switch (status) {
      case UpdateStatus.available:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _GhostButton(label: 'Later', onPressed: _dismiss),
            const SizedBox(width: 12),
            _PrimaryButton(
              label: 'Download & Install',
              icon: Icons.cloud_upload_rounded,
              onPressed: _startDownload,
            ),
          ],
        );

      case UpdateStatus.readyToRestart:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _GhostButton(label: 'Cancel', onPressed: _dismiss),
            const SizedBox(width: 12),
            _PrimaryButton(
              label: 'Restart Now',
              icon: Icons.restart_alt_rounded,
              onPressed: _restart,
            ),
          ],
        );

      case UpdateStatus.downloading:
        // No actions while downloading — close button is hidden too
        return const SizedBox.shrink();

      case UpdateStatus.upToDate:
      case UpdateStatus.error:
      case UpdateStatus.checking:
      case UpdateStatus.idle:
        return Align(
          alignment: Alignment.centerRight,
          child: _GhostButton(label: 'Close', onPressed: _dismiss),
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData _headerIcon(UpdateStatus s) {
    switch (s) {
      case UpdateStatus.readyToRestart:
        return Icons.restart_alt_rounded;
      case UpdateStatus.available:
        return Icons.cloud_upload_rounded;
      case UpdateStatus.downloading:
        return Icons.cloud_sync_rounded;
      case UpdateStatus.upToDate:
        return Icons.verified_rounded;
      case UpdateStatus.error:
        return Icons.error_outline_rounded;
      default:
        return Icons.cloud_upload_rounded;
    }
  }

  String _headerTitle(UpdateStatus s) {
    switch (s) {
      case UpdateStatus.checking:
        return 'Checking for Updates';
      case UpdateStatus.available:
        return 'Update Available';
      case UpdateStatus.downloading:
        return 'Downloading Update';
      case UpdateStatus.readyToRestart:
        return 'Ready to Update';
      case UpdateStatus.upToDate:
        return 'Up to Date';
      case UpdateStatus.error:
        return 'Update Error';
      default:
        return 'Software Update';
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CenteredStatus extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  final Color iconColor;
  final bool spinning;

  const _CenteredStatus({
    required this.icon,
    required this.message,
    required this.subtitle,
    this.iconColor = kOnSurfaceVariant,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        spinning
            ? SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimary,
                ),
              )
            : Icon(icon, size: 48, color: iconColor),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: kOnSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: kOnSurfaceVariant),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String current;
  final String next;
  const _VersionBadge({required this.current, required this.next});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _VersionChip(label: current, dim: true),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded,
              size: 16, color: kOnSurfaceVariant),
        ),
        _VersionChip(label: next, dim: false),
      ],
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String label;
  final bool dim;
  const _VersionChip({required this.label, required this.dim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dim ? const Color(0x0DFFFFFF) : kNeonGlowBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: dim ? Colors.white12 : kNeonGlowBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: dim ? kOnSurfaceVariant : kPrimary,
          fontFamily: 'SpaceGrotesk',
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: const Color(0xFF003919),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GhostButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: kOnSurface,
        side: const BorderSide(color: Colors.white24),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999)),
      ),
      child:
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
