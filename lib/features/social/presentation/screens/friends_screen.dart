import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/retryable_error.dart';
import '../../application/social_providers.dart';
import '../widgets/person_row.dart';

/// Search for other users and follow them, or browse who you already
/// follow — the entry point for "add friends to a group chat" later.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search people by name',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _query.isEmpty
                  ? const _FollowingList()
                  : _SearchResults(query: _query),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingList extends ConsumerWidget {
  const _FollowingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final textTheme = Theme.of(context).textTheme;

    return followingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryableError(
        message: 'Could not load who you follow.',
        onRetry: () => ref.invalidate(followingProvider),
      ),
      data: (following) {
        if (following.isEmpty) {
          return Center(
            child: Text(
              'Search above to find and follow people.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          );
        }
        return ListView.separated(
          itemCount: following.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) =>
              PersonRow(person: following[index], following: true),
        );
      },
    );
  }
}

/// Watches [searchResultsProvider], keyed by the query text — unlike a
/// `FutureBuilder` with its future built inline, this doesn't restart
/// (and flash back to loading) every time something unrelated in the
/// tree rebuilds, which used to make results flicker on and off and be
/// impossible to tap.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider(query));
    final followingAsync = ref.watch(followingProvider);
    final followingIds =
        followingAsync.value?.map((f) => f.userId).toSet() ?? const {};

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryableError(
        message: 'Could not search right now.',
        onRetry: () => ref.invalidate(searchResultsProvider(query)),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Text(
              'No one found for "$query".',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) => PersonRow(
            person: results[index],
            following: followingIds.contains(results[index].userId),
          ),
        );
      },
    );
  }
}
