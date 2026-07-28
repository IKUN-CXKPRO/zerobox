import 'package:flutter/material.dart';

class HuamiBrandIcon extends StatelessWidget {
  const HuamiBrandIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(
      child: Text(
        '∑',
        semanticsLabel: 'Amazfit',
        style: TextStyle(
          color: IconTheme.of(context).color,
          fontSize: size * .9,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    ),
  );
}
