import 'dart:convert';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<dynamic> _allTransactions = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Filter: 0 = All, 1 = Credit, 2 = Debit
  int _filterIndex = 0;

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
        Uri.parse('${ApiUrls.driverWalletTransactionsUrl}?page=1&limit=30'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        final pagination = data['pagination'] ?? {};
        setState(() {
          _allTransactions = data['transactions'] ?? [];
          _totalPages = pagination['pages'] ?? 1;
          _page = 1;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final response = await http.get(
        Uri.parse(
            '${ApiUrls.driverWalletTransactionsUrl}?page=$nextPage&limit=30'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        setState(() {
          _allTransactions.addAll(data['transactions'] ?? []);
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

  List<dynamic> get _filteredTransactions {
    if (_filterIndex == 0) return _allTransactions;
    final type = _filterIndex == 1 ? 'CREDIT' : 'DEBIT';
    return _allTransactions.where((t) => t['type'] == type).toList();
  }

  String _formatDescription(dynamic txn) {
    final desc = txn['description'] ?? '';
    if (desc == 'Refund - Trip Issue') return 'Trip Adjustment';
    return desc.isNotEmpty
        ? desc
        : (txn['type'] == 'CREDIT' ? 'Credit' : 'Debit');
  }

  String _formatDate(dynamic txn) {
    final dateStr = txn['createdAt'] ?? '';
    if (dateStr is String && dateStr.isNotEmpty) {
      final date = DateTime.tryParse(dateStr)?.toLocal();
      if (date != null) return DateFormat('dd MMM, hh:mm a').format(date);
    }
    return '';
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
                  Text(
                    'transactions'.tr,
                    style: const TextStyle(
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

          // Filter tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip(0, 'all'.tr),
                const SizedBox(width: 10),
                _buildFilterChip(1, 'credit'.tr),
                const SizedBox(width: 10),
                _buildFilterChip(2, 'debit'.tr),
              ],
            ),
          ),

          Expanded(
            // Pull-to-refresh, as the wallet screen has: a settlement landing
            // while this page sat open otherwise never appeared without
            // re-entering.
            child: _loading
                ? Center(
                    child:
                        CircularProgressIndicator(color: AppColors.appColor))
                : RefreshIndicator(
                    color: AppColors.appColor,
                    onRefresh: _fetchTransactions,
                    child: _filteredTransactions.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 200),
                              Center(
                                  child: Text('no_transactions'.tr,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.grey))),
                            ],
                          )
                        : _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.appColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final transactions = _filteredTransactions;
    return ListView.builder(
      controller: _scrollController,
      // Always scrollable so pull-to-refresh works on a short list too.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: transactions.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == transactions.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildTransactionTile(transactions[index]);
      },
    );
  }

  Widget _buildTransactionTile(dynamic txn) {
    final type = txn['type'] ?? '';
    final isCredit = type == 'CREDIT';
    final amount = (txn['amount'] ?? 0).toDouble();
    final description = _formatDescription(txn);
    final dateStr = _formatDate(txn);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isCredit
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
          Text(
            "${isCredit ? '+' : '-'} \u20B9${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isCredit
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }
}
