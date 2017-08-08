# Kubernetes conformance tests

This is a standalone container able to launch Kubernetes end-to-end tests, for the purposes of conformance testing.

It is a thin wrapper around the `e2e.test` binary in the upstream Kubernetes distribution, which drops results in a predetermined location for use as a [Heptio Sonobuoy](https://github.com/heptio/sonobuoy) plugin.

To learn more about conformance testing and its Sonobuoy integration, read the [conformance guide](https://github.com/heptio/sonobuoy/blob/master/docs/conformance-testing.md).
