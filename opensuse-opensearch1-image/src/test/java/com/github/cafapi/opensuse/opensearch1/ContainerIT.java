/*
 * Copyright 2017-2024 Open Text.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.github.cafapi.opensuse.opensearch1;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.util.Collections;
import java.util.Map;
import java.util.Optional;

import org.apache.http.HttpHost;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.conn.ssl.NoopHostnameVerifier;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.ssl.SSLContextBuilder;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TestRule;
import org.junit.rules.TestWatcher;
import org.junit.runner.Description;
import org.opensearch.client.RestClient;
import org.opensearch.client.RestClientBuilder;
import org.opensearch.client.json.jackson.JacksonJsonpMapper;
import org.opensearch.client.opensearch.OpenSearchClient;
import org.opensearch.client.opensearch._types.ExpandWildcard;
import org.opensearch.client.opensearch._types.HealthStatus;
import org.opensearch.client.opensearch._types.mapping.Property;
import org.opensearch.client.opensearch.cluster.HealthRequest;
import org.opensearch.client.opensearch.cluster.HealthResponse;
import org.opensearch.client.opensearch.indices.CreateIndexRequest;
import org.opensearch.client.opensearch.indices.CreateIndexResponse;
import org.opensearch.client.opensearch.indices.IndexSettings;
import org.opensearch.client.transport.OpenSearchTransport;
import org.opensearch.client.transport.rest_client.RestClientTransport;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class ContainerIT {

    private static final int CONNECT_TIMEOUT = 60000;
    private static final int SOCKET_TIMEOUT = 60000;
    private static final Logger LOGGER = LoggerFactory.getLogger(ContainerIT.class);

    @Rule
    public TestRule watcher = new TestWatcher() {
        @Override
        protected void starting(final Description description) {
            LOGGER.info("Running test: {}", description.getMethodName());
        }
    };

    @Test
    public void testIndexCreation() throws IOException, InterruptedException {
        try (final RestClient restClient = getOpenSearchRestClient();
            final OpenSearchTransport transport = getOpenSearchTransport(restClient);) {
            final OpenSearchClient client = new OpenSearchClient(transport);

            final HealthRequest.Builder builder = new HealthRequest.Builder();
            builder.expandWildcards(ExpandWildcard.All);
            builder.index("*", "-.*");
            final HealthRequest request = builder.build();
            LOGGER.info("Running HealthCheck...");
            final HealthResponse response = client.cluster().health(request);

            final HealthStatus status = response.status();

            LOGGER.info("Got HealthStatus :{}", status.jsonValue());
            assertEquals("Elasticsearch status not green", HealthStatus.Green, status);

            // Create an index
            final String index = "container_test";
            final IndexSettings.Builder settingsBuilder = new IndexSettings.Builder();
            settingsBuilder.numberOfShards("1");
            settingsBuilder.numberOfReplicas("0");
            final IndexSettings indexSettings = settingsBuilder.build();

            final CreateIndexRequest.Builder indexBuilder = new CreateIndexRequest.Builder();
            indexBuilder.index(index);
            indexBuilder.settings(indexSettings);

            final Map<String, Property> fields = Collections.singletonMap("text", Property.of(p -> p.text(f -> f.store(false))));
            final Property text = Property.of(p -> p.text(t -> t.fields(fields)));
            indexBuilder.mappings(m -> m.properties("message", text));

            final CreateIndexRequest createIndexRequest = indexBuilder.build();

            LOGGER.info("Creating index...");
            final CreateIndexResponse createIndexResponse = client.indices().create(createIndexRequest);

            assertTrue("Index response was not acknowledged", createIndexResponse.acknowledged());
            assertTrue("All shards were not copied", createIndexResponse.shardsAcknowledged());
        }
    }

    private OpenSearchTransport getOpenSearchTransport(final RestClient restClient) {
        LOGGER.info("Creating OpenSearchTransport...");
        final OpenSearchTransport transport = new RestClientTransport(restClient, new JacksonJsonpMapper());
        return transport;
    }

    private RestClient getOpenSearchRestClient() {
        LOGGER.info("getOpenSearchRestClient...");
        final String userName = Optional.ofNullable(System.getProperty("user")).orElse("admin");
        final String password = Optional.ofNullable(System.getProperty("password")).orElse("admin");

        final CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
        credentialsProvider.setCredentials(AuthScope.ANY, new UsernamePasswordCredentials(userName, password));
        LOGGER.info("Server URL {}://{}:{}",
            System.getenv("OPENSEARCH_SCHEME"), System.getenv("OPENSEARCH_HOST"), System.getenv("OPENSEARCH_PORT"));

        final HttpHost httpHost = new HttpHost(System.getenv("OPENSEARCH_HOST"), Integer.parseInt(System.getenv("OPENSEARCH_PORT")),
            System.getenv("OPENSEARCH_SCHEME"));
        final RestClientBuilder builder = RestClient.builder(httpHost);

        builder.setRequestConfigCallback(
            requestConfigBuilder -> requestConfigBuilder.setConnectTimeout(CONNECT_TIMEOUT).setSocketTimeout(SOCKET_TIMEOUT));

        builder.setHttpClientConfigCallback(httpAsyncClientBuilder -> httpAsyncClientBuilder);

        builder.setHttpClientConfigCallback(httpClientBuilder -> {
            {
                httpClientBuilder.setDefaultCredentialsProvider(credentialsProvider)
                    .setSSLHostnameVerifier(NoopHostnameVerifier.INSTANCE).setKeepAliveStrategy(
                        (response, context) -> 3600000/* 1hour */);
                try {
                    httpClientBuilder
                        .setSSLContext(SSLContextBuilder.create().loadTrustMaterial(null, (chains, authType) -> true).build());
                } catch (final KeyManagementException | NoSuchAlgorithmException | KeyStoreException e) {
                    LOGGER.error("Error configuring http client", e);
                }
                return httpClientBuilder;
            }
        });

        LOGGER.info("Creating RestClient...");
        return builder.build();
    }

}
