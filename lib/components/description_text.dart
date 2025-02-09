import 'package:flutter/material.dart';

class DescriptionText extends StatefulWidget {
  final String text;
  const DescriptionText({super.key, required this.text});

  @override
  State<DescriptionText> createState() => _DescriptionTextState();
}

class _DescriptionTextState extends State<DescriptionText> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(
          text: widget.text,
          style: TextStyle(fontSize: 16, color: Colors.grey[200]),
        );

        final tp = TextPainter(
          text: span,
          maxLines: 3,
          textDirection: TextDirection.ltr,
        );

        tp.layout(maxWidth: constraints.maxWidth);

        if (tp.didExceedMaxLines) {
          return RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: isExpanded ? widget.text : "${widget.text.substring(0, widget.text.length ~/ 2)}... ",
                  style: TextStyle(fontSize: 16, color: Colors.grey[200]),
                ),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => setState(() => isExpanded = !isExpanded),
                    child: Text(
                      isExpanded ? "Show Less" : "Show More",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Text(
          widget.text,
          style: TextStyle(fontSize: 16, color: Colors.grey[200]),
        );
      },
    );
  }
}
