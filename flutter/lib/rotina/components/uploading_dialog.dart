import 'package:flutter/material.dart';

class UploadingDialog extends StatelessWidget {
  final String message;

  const UploadingDialog({super.key, this.message = 'Enviando fotos...'});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Open Sans'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
