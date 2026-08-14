import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Month-grouped wallet transaction rows, shared by MyWalletScreen (the latest
/// rows returned inline by /driver/wallet) and TransactionsScreen (the paginated
/// /driver/wallet/transactions list, optionally pre-filtered to CREDIT/DEBIT).
///
/// It lives in one file because both screens render the *same* WalletTransaction
/// documents, and while the row markup was duplicated the two had already
/// drifted: the wallet screen formatted amounts with zero decimals
/// (NumberFormat decimalDigits: 0) while the transactions screen used two, so
/// the same ₹873.01 row read as "₹873" on one screen and "₹873.01" on the other.

/// Two decimals, because these are exact ledger amounts — rounding a balance or
/// a settlement line to whole rupees misstates it.
final NumberFormat walletMoney =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

const Color kCreditGreen = Color(0xFF1B9C57);
const Color kDebitRed = Color(0xFFD32F2F);

/// The remap predates this widget: the backend writes the literal
/// "Refund - Trip Issue" for driver-side adjustments, which reads to a driver as
/// an accusation about their trip. Kept identical to what both screens already
/// did so no wording changes as a side effect of sharing the code.
String walletTransactionTitle(dynamic txn) {
  final desc = (txn['description'] ?? '').toString();
  if (desc == 'Refund - Trip Issue') return 'Trip Adjustment';
  if (desc.isNotEmpty) return desc;
  return txn['type'] == 'CREDIT' ? 'credit'.tr : 'debit'.tr;
}

DateTime? _txnDate(dynamic txn) {
  final raw = txn['createdAt'];
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toLocal();
  return null;
}

/// Groups consecutive rows by calendar month. The server sorts by createdAt
/// descending, so a single pass is enough. Rows whose createdAt is missing or
/// unparseable get a null label and simply render without a month rule rather
/// than being filed under a guessed month.
List<Widget> buildMonthGroupedTransactions(List<dynamic> transactions) {
  final labels = <String?>[];
  final buckets = <List<dynamic>>[];

  for (final txn in transactions) {
    final date = _txnDate(txn);
    final label =
        date == null ? null : DateFormat('MMMM yyyy').format(date).toUpperCase();
    if (buckets.isEmpty || labels.last != label) {
      labels.add(label);
      buckets.add(<dynamic>[txn]);
    } else {
      buckets.last.add(txn);
    }
  }

  final widgets = <Widget>[];
  for (var i = 0; i < buckets.length; i++) {
    final label = labels[i];
    if (label != null) widgets.add(_monthDivider(label));
    widgets.add(_monthBlock(buckets[i]));
  }
  return widgets;
}

Widget _monthDivider(String label) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
    child: Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFE3E5EA))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFE3E5EA))),
      ],
    ),
  );
}

Widget _monthBlock(List<dynamic> rows) {
  final children = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) {
      children.add(const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFF0F1F4),
        indent: 16,
        endIndent: 16,
      ));
    }
    children.add(walletTransactionRow(rows[i]));
  }
  return Container(color: Colors.white, child: Column(children: children));
}

Widget walletTransactionRow(dynamic txn) {
  final isCredit = txn['type'] == 'CREDIT';
  final amount = ((txn['amount'] ?? 0) as num).toDouble();
  final reference = (txn['referenceId'] ?? '').toString();
  final date = _txnDate(txn);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                walletTransactionTitle(txn),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2430),
                ),
              ),
              // referenceId is optional on WalletTransaction, so the line only
              // appears when the document actually carries one — no synthesised
              // or _id-derived stand-in.
              if (reference.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  '${'reference_id'.tr}: $reference',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
              // The month rule above only narrows a row to its month; the exact
              // timestamp is real and is the thing a driver quotes to support,
              // so it is kept beneath the reference rather than dropped.
              if (date != null) ...[
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM, hh:mm a').format(date),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${isCredit ? '+' : '-'} ${walletMoney.format(amount)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isCredit ? kCreditGreen : kDebitRed,
          ),
        ),
      ],
    ),
  );
}
