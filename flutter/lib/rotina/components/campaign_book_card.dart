import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inventario/rotina/theme.dart';
import 'package:inventario/rotina/types.dart';

/// Card de book pendente exibido na Rotina do dia (barra amarela à esquerda).
class CampaignBookCard extends StatelessWidget {
  final BookStatus book;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onView;
  final bool minimalista;

  const CampaignBookCard({
    super.key,
    required this.book,
    this.onAddPhoto,
    this.onView,
    this.minimalista = false,
  });

  String get _itemLabel {
    final desc = book.item?['description']?.toString() ?? '';
    if (desc.isNotEmpty) return desc;
    if (book.type.toLowerCase() == 'management') return 'Administrativo';
    return book.type.isNotEmpty ? book.type : '—';
  }

  String get _prazo {
    final d = DateTime.tryParse(book.endDateTime);
    if (d == null) return book.endDateTime;
    final p = (int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  Widget _buildMinimal() {
    final pendente = book.pendente;
    return GestureDetector(
      onTap: onView,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: Colors.amber[600]),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontFamily: 'Open Sans',
                              ),
                              children: [
                                const TextSpan(
                                    text: 'Book: ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(
                                  text: book.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pendente
                                ? Colors.amber[300]
                                : const Color(0xFFC8E6C9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pendente ? 'Não enviado' : 'Enviado',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              fontFamily: 'Open Sans',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (minimalista) return _buildMinimal();
    final pendente = book.pendente;
    const textStyle = TextStyle(
      fontSize: 14,
      color: Colors.black87,
      fontFamily: 'Open Sans',
      height: 1.3,
    );
    const labelStyle = TextStyle(fontWeight: FontWeight.bold);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 10, color: Colors.amber[600]),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(style: textStyle, children: [
                        const TextSpan(text: 'Book: ', style: labelStyle),
                        TextSpan(
                          text: book.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        ),
                      ])),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(style: textStyle, children: [
                          const TextSpan(
                              text: 'Descrição: ', style: labelStyle),
                          TextSpan(
                              text:
                                  book.description.isEmpty ? '—' : book.description),
                        ]),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(style: textStyle, children: [
                                const TextSpan(
                                    text: 'Item: ', style: labelStyle),
                                TextSpan(text: _itemLabel),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text.rich(
                            TextSpan(style: textStyle, children: [
                              const TextSpan(
                                  text: 'Prazo: ', style: labelStyle),
                              TextSpan(text: _prazo),
                            ]),
                            maxLines: 1,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Status: ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'Open Sans',
                              )),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: pendente
                                  ? Colors.amber[300]
                                  : const Color(0xFFC8E6C9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pendente ? 'Não enviado' : 'Enviado',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                fontFamily: 'Open Sans',
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (book.podeEnviarFotos && onAddPhoto != null)
                            IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                  minWidth: 34, minHeight: 34),
                              icon: SvgPicture.asset(
                                'assets/rotina/icons/books_add_image.svg',
                                width: 20,
                                height: 21,
                                colorFilter: const ColorFilter.mode(
                                    AppColors.primary, BlendMode.srcIn),
                              ),
                              onPressed: onAddPhoto,
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                                minWidth: 34, minHeight: 34),
                            icon: SvgPicture.asset(
                              'assets/rotina/icons/books_eye.svg',
                              width: 24,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                  AppColors.primary, BlendMode.srcIn),
                            ),
                            onPressed: onView,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
