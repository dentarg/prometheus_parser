require "./spec/config"
require "./lib/prometheus_parser"

describe PrometheusParser do
  it "should parse simple metric" do
    raw = <<~METRICS
      response_packet_get_children_cache_hits 0.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "response_packet_get_children_cache_hits"
    _(res.first[:value]).must_equal 0.0
    _(res.first[:attrs]).must_be_empty
  end

  it "should parse many metrics" do
    raw = <<~METRICS
      kafka_cluster_partition_underminisr 0
      kafka_network_requestmetrics_totaltimems 179494
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 2
    _(res.first[:key]).must_equal "kafka_cluster_partition_underminisr"
    _(res.first[:value]).must_equal 0.0
    _(res.first[:attrs]).must_be_empty
    _(res[1][:key]).must_equal "kafka_network_requestmetrics_totaltimems"
    _(res[1][:value]).must_equal 179_494
    _(res[1][:attrs]).must_be_empty
  end

  it "should parse attrs" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics{network_processor="8",listener="sasl_ssl",key="connection-count"} 0.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "kafka_server_socket_server_metrics"
    _(res.first[:value]).must_equal 0.0
    attrs = {
      network_processor: "8",
      listener: "sasl_ssl",
      key: "connection-count"
    }
    _(res.first[:attrs]).must_equal attrs
  end

  it "should parse attrs with spaces" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics{network_processor = "8" , listener="sasl_ssl" ,key="connection-count"} 0.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "kafka_server_socket_server_metrics"
    _(res.first[:value]).must_equal 0.0
    attrs = {
      network_processor: "8",
      listener: "sasl_ssl",
      key: "connection-count"
    }
    _(res.first[:attrs]).must_equal attrs
  end

  it "should skip comments" do
    raw = <<~METRICS
      # HELP .................
      # TYPE ...................
      kafka_server_socket_server_metrics{network_processor="8",listener="sasl_ssl",key="connection-count"} 0.0
    METRICS

    res = PrometheusParser.parse(raw)
    _(res.size).must_equal 1
    _(res.first[:key]).must_equal "kafka_server_socket_server_metrics"
  end

  it "should raise error on bad key" do
    raw = <<~METRICS
      kafka!_server_socket_server_metrics 0.0
    METRICS
    assert_raises PrometheusParser::Invalid do
      PrometheusParser.parse(raw)
    end
  end

  it "should handle NaN values" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics NaN
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:value]).must_equal 0.0
  end

  it "should handle 8.123213E-28" do
    raw = <<~METRICS
      kafka_server_socket_server_metrics 8.123213E-28
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:value]).must_equal 8.123213e-28
  end

  it "should handle quoted values in attributes" do
    raw = <<~METRICS
      kafka_log_LogManager_Value{name="LogDirectoryOffline",logDirectory="\"/var/lib/kafka\"",} 0.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:name]).must_equal "LogDirectoryOffline"
    _(res.first[:attrs][:logDirectory]).must_equal "\"/var/lib/kafka\""
    _(res.first[:value]).must_equal 0.0
  end

  it "should handle decimals values in attributes" do
    raw = <<~METRICS
      concurrent_request_processing_in_commit_processor{quantile="0.5",} NaN
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:quantile]).must_equal "0.5"
    _(res.first[:value]).must_equal 0
  end

  it "should handle space values in attributes" do
    raw = <<~METRICS
      jvm_memory_pool_allocated_bytes_total{pool="CodeHeap 'non-profiled nmethods'",} 2387840.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:pool]).must_equal "CodeHeap 'non-profiled nmethods'"
    _(res.first[:value]).must_equal 2_387_840.0
  end

  it "should handle plus (+) values in attributes" do
    raw = <<~METRICS
      jvm_info{version="11.0.16+8-post-Debian-1deb11u1",vendor="Debian",runtime="OpenJDK Runtime Environment",} 1.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:version]).must_equal "11.0.16+8-post-Debian-1deb11u1"
  end

  it "should ... " do
    raw = <<~METRICS
      jvm_info{runtime="OpenJDK Runtime Environment",vendor="Private Build",version="1.8.0_362-8u362-ga-0ubuntu1~20.04.1-b09",} 1.0
    METRICS
    res = PrometheusParser.parse(raw)
    _(res.first[:attrs][:version]).must_equal "1.8.0_362-8u362-ga-0ubuntu1~20.04.1-b09"
  end
end
