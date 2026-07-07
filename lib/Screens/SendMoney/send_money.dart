import 'dart:convert';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


class SendMoney extends StatefulWidget {
  const SendMoney({super.key});

  @override
  State<SendMoney> createState() => _SendMoneyState();
}

class _SendMoneyState extends State<SendMoney> {
  List<dynamic> _transactions = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _page < _totalPages) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrls.driverWalletTransactionsUrl}?page=1&limit=20'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        final all = data['transactions'] ?? [];
        final pagination = data['pagination'] ?? {};
        setState(() {
          _transactions =
              all.where((t) => t['type'] == 'DEBIT').toList();
          _totalPages = pagination['pages'] ?? 1;
          _page = 1;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching send transactions: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final response = await http.get(
        Uri.parse(
            '${ApiUrls.driverWalletTransactionsUrl}?page=$nextPage&limit=20'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        final all = data['transactions'] ?? [];
        setState(() {
          _transactions
              .addAll(all.where((t) => t['type'] == 'DEBIT').toList());
          _page = nextPage;
          _loadingMore = false;
        });
      } else {
        setState(() => _loadingMore = false);
      }
    } catch (e) {
      setState(() => _loadingMore = false);
    }
  }

  Map<String, List<dynamic>> _groupByMonth() {
    final Map<String, List<dynamic>> grouped = {};
    for (final txn in _transactions) {
      final createdAt = txn['createdAt'] ?? '';
      DateTime? date;
      if (createdAt is String && createdAt.isNotEmpty) {
        date = DateTime.tryParse(createdAt)?.toLocal();
      }
      final label = date != null
          ? DateFormat('MMMM yyyy').format(date).toUpperCase()
          : 'UNKNOWN';
      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(txn);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: Column(
        children: [
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      width: 40,
                      height: 35,
                      alignment: Alignment.center,
                      child: Image.asset("assets/back_arrow.png",
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Send Amount",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(
                        child: Text('no_debit_transactions'.tr,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey)))
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = _groupByMonth();
    final List<Widget> children = [];

    for (final entry in grouped.entries) {
      children.add(Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Divider(thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(entry.key,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey[700])),
            ),
            const Expanded(child: Divider(thickness: 1)),
          ],
        ),
      ));
      children.add(Container(height: 8, color: Colors.white));

      for (final txn in entry.value) {
        children.add(_buildTransactionTile(txn));
      }
    }

    if (_loadingMore) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ));
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: children,
    );
  }

  Widget _buildTransactionTile(dynamic txn) {
    final amount = (txn['amount'] ?? 0).toDouble();
    final description = txn['description'] ?? 'Debit';
    final referenceId = txn['referenceId'] ?? '';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text("${'reference_id'.tr}: $referenceId",
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 10)),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              Text(
                "- ₹${amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              )
            ],
          ),
        ),
        Container(
          height: 0.5,
          width: MediaQuery.of(context).size.width,
          color: Colors.grey[400],
        )
      ],
    );
  }
}
