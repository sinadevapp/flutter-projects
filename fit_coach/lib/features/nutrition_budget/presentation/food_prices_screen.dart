import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/nutrition_budget/application/food_providers.dart';
import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the coach records what food costs in their own market.
///
/// The list is deliberately in storage order, not ranked: a coach working
/// down the list must not have rows jump around as prices come in. The
/// *computed* cost per gram of protein updates live next to each row, which is
/// what makes the trade-off visible while entering prices.
class FoodPricesScreen extends ConsumerWidget {
  const FoodPricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(allFoodsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.foodPrices)),
      body: foods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) => rows.isEmpty
            ? Center(child: Text(l10n.noFoodsYet))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.foodPricesHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) =>
                          _FoodRowTile(row: rows[i], rank: i + 1),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FoodRowTile extends ConsumerWidget {
  const _FoodRowTile({required this.row, required this.rank});

  final FoodRow row;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final food = foodToItem(row);
    final cost = food.costPerGramProtein;

    return ListTile(
      leading: CircleAvatar(child: Text(localizeNumber(locale, rank))),
      title: Text(food.name),
      subtitle: Text(
        '${l10n.proteinPer100g}: ${localizeNumber(locale, food.proteinPer100g.round())}'
        ' • ${l10n.kcalPer100g}: ${localizeNumber(locale, food.kcalPer100g.round())}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (cost == null)
            // A blank price is a prompt, not an error: the coach has simply
            // not been to the market yet.
            Text(
              l10n.noPriceYet,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text(localizeNumber(locale, cost.round())),
          if (cost != null)
            Text(
              l10n.costPerGramProtein,
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      onTap: () => _editPrice(context, ref),
    );
  }

  Future<void> _editPrice(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<int?>(
      context: context,
      builder: (_) => _PriceDialog(food: foodToItem(row)),
    );
    // Null means the dialog was dismissed — not "clear the price". Clearing is
    // expressed by submitting an empty field, which yields 0 from the dialog.
    if (value == null) return;

    await ref
        .read(appDatabaseProvider)
        .updateFoodPrice(row.id, value == 0 ? null : value);

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.priceSaved)));
    }
  }
}

/// Asks for a price per kilo. Submitting an empty field clears the price.
class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.food});

  final FoodItem food;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.food.pricePerKg?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    // Empty clears the price. Both paths return a non-null int so the caller
    // can tell "submitted" apart from "dismissed".
    if (text.isEmpty) {
      Navigator.of(context).pop(0);
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      // Leave the dialog open on nonsense rather than storing it.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.invalidPrice)),
      );
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.enterPriceFor(widget.food.name)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.pricePerKg,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
