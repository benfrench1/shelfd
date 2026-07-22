## Note on Global reviews retrieved from HardCover API

The HardCover personal token API appears to be scoped to one's own data only — it will not return other users' user_books entries regardless of query structure. Their row-level security blocks all access to other users' reviews unless you specifically follow them on HardCover.

The HardCover integration as designed is not feasible with a personal API token. The feature would only ever show:
- A users own logged book (if you've read it on HardCover)
- Reviews from people you personally follow on HardCover


> [!NOTE]
> Doe to these reasons above it was not possible to proceed with this as an option
