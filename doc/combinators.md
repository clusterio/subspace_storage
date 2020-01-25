# Clusterio Combinators

Clusterio provides various combinators for connecting circuits between worlds and to the cluster itself.


## Inventory Combinator

  * Provides signals reporting inventory status of the cluster's storage, similar to roboport inventory reports.
  * Provides `signal-unixtime` with a real time signal. This can be used to monitor UPS and connectivity.
  * Provides `signal-localid` indicating this world's ID within the cluster.

## Transmit and Receive Combinators

Unfortunately the implementation of these were just too buggy and unstable to be used and they have therefore
been removed.
