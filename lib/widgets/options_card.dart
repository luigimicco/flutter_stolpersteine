import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OptionCard extends StatelessWidget {
  final String label;
  final String caption;

  const OptionCard({super.key, required this.label, required this.caption});

  @override
  Widget build(BuildContext context) {
    bool isUrl = false;
    isUrl = caption.toString().startsWith("http://") ||
        caption.toString().startsWith("https://");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label
                    .replaceFirst("addr:", "")
                    .replaceFirst("object:", "")
                    .replaceFirst("memorial:", "")
                    .replaceFirst("person:", ""),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          InkWell(
            onTap: (isUrl)
                ? () async {
                    final Uri url = Uri.parse(caption.toString());
                    try {
                      await launchUrl(url);
                    } catch (e) {}
                  }
                : null,
            child: Text(
              caption,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: (isUrl) ? Colors.blueAccent : Colors.black,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
