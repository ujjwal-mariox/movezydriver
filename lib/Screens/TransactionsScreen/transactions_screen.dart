import 'dart:convert';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/MyWallet/Widgets/wallet_transaction_list.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

/// Filter values shared with callers so the wallet's Send/Received tiles don't
/// have to hardcode the magic ints this screen's chips use.
class TransactionFilter {
  static const int all = 0;
  static const int credit = 1;
  static const int debit = 2;
}

class TransactionsScreen extends StatefulWidget {
  /// Which chip is active on open — one of [TransactionFilter]. The wallet's
  /// "Send Amount" / "Received Amount" tiles open this same screen pre-filtered
  /// to DEBIT / CREDIT instead of there being three near-identical screens.
  final int initialFilter;

  /// App-bar title override, so a pre-filtered entry point can name what it is
  /// showing ("Send Amount") rather than the generic "Transactions".
  final String? title;

  /// Hidden on the pre-filtered entry points: the title there already names the
  /// filter, so leaving the chips tappable would let the header contradict the
  /// list. The unfiltered "Wallet Statement" entry keeps them.
  final bool showFilters;

  const TransactionsScreen({
    super.key,
    this.initialFilter = TransactionFilter.all,
    this.title,
    this.showFilters = true,
  });

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
  late int _filterIndex = widget.initialFilter;

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
      // mounted guards: these setStates sit after an await, and the drain loop
      // below can still have a request in flight when the driver backs out.
      if (!mounted) return;
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
        await _drainPagesForEmptyFilter();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Returns whether the page actually advanced, so the drain loop below can
  /// stop instead of retrying a failing request forever.
  Future<bool> _loadMore() async {
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
      if (!mounted) return false;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        setState(() {
          _allTransactions.addAll(data['transactions'] ?? []);
          _page = nextPage;
          _loadingMore = false;
        });
        return true;
      }
      setState(() => _loadingMore = false);
      return false;
    } catch (e) {
      debugPrint('Error loading more transactions: $e');
      if (mounted) setState(() => _loadingMore = false);
      return false;
    }
  }

  List<dynamic> get _filteredTransactions {
    if (_filterIndex == TransactionFilter.all) return _allTransactions;
    final type =
        _filterIndex == TransactionFilter.credit ? 'CREDIT' : 'DEBIT';
    return _allTransactions.where((t) => t['type'] == type).toList();
  }

  /// The filter is applied to the rows already downloaded, so a driver whose
  /// first page happens to be all credits used to open "Send Amount" (or tap the
  /// Debit chip) and be told they had no transactions at all — with no way to
  /// reach the later pages, because the infinite-scroll listener only fires on a
  /// list that has something to scroll. Pull pages until the filter matches
  /// something or the history runs out.
  Future<void> _drainPagesForEmptyFilter() async {
    while (mounted &&
        _filterIndex != TransactionFilter.all &&
        _filteredTransactions.isEmpty &&
        _page < _totalPages &&
        !_loadingMore) {
      // Stop on a failed page rather than re-requesting it forever.
      if (!await _loadMore()) return;
    }
  }

  /// Says which slice is empty. "No transactions yet" under a Send Amount header
  /// claims the driver has no wallet history at all, which is usually false —
  /// they just have no debits.
  String get _emptyMessage {
    switch (_filterIndex) {
      case TransactionFilter.credit:
        return 'No amounts received yet';
      case TransactionFilter.debit:
        return 'No amounts sent yet';
      default:
        return 'no_transactions'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
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
                  // Flexible: as a bare Row child the title got unbounded width,
                  // so a long override or translation overflowed instead of
                  // ellipsizing.
                  Flexible(
                    child: Text(
                      widget.title ?? 'transactions'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // Filter tabs
          if (widget.showFilters)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildFilterChip(TransactionFilter.all, 'all'.tr),
                  const SizedBox(width: 10),
                  _buildFilterChip(TransactionFilter.credit, 'credit'.tr),
                  const SizedBox(width: 10),
                  _buildFilterChip(TransactionFilter.debit, 'debit'.tr),
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
                              const SizedBox(height: 180),
                              Center(
                                  child: Text(_emptyMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.grey))),
                              // Only shown while pages remain: the filter runs
                              // client-side, so an empty slice does not mean an
                              // empty history. _drainPagesForEmptyFilter() is
                              // already fetching when this appears.
                              if (_loadingMore) ...[
                                const SizedBox(height: 16),
                                Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.appColor),
                                  ),
                                ),
                              ],
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
      onTap: () {
        setState(() => _filterIndex = index);
        // Switching to Credit/Debit can empty the downloaded slice; pull further
        // pages so the chip doesn't read as "you have none".
        _drainPagesForEmptyFilter();
      },
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
    // Grouping needs the whole page of rows to find month boundaries, so the
    // group widgets are assembled up front and the ListView just indexes into
    // them; a page is 30 rows, so nothing large is built eagerly.
    final rows = buildMonthGroupedTransactions(_filteredTransactions);
    return ListView.builder(
      controller: _scrollController,
      // Always scrollable so pull-to-refresh works on a short list too.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: rows.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.appColor),
            ),
          );
        }
        return rows[index];
      },
    );
  }

}
