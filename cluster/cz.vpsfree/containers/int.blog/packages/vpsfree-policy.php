<?php
/**
 * Plugin Name: vpsFree.cz WordPress policy
 * Description: Keeps application updates in Nix and requires HTTPS for external WordPress HTTP requests.
 * Version: 1.0.2
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// Nix owns core, plugin, theme, and translation updates.
remove_action( 'admin_init', '_maybe_update_core' );
remove_action( 'wp_version_check', 'wp_version_check' );

remove_action( 'load-plugins.php', 'wp_update_plugins' );
remove_action( 'load-update.php', 'wp_update_plugins' );
remove_action( 'load-update-core.php', 'wp_update_plugins' );
remove_action( 'admin_init', '_maybe_update_plugins' );
remove_action( 'wp_update_plugins', 'wp_update_plugins' );

remove_action( 'load-themes.php', 'wp_update_themes' );
remove_action( 'load-update.php', 'wp_update_themes' );
remove_action( 'load-update-core.php', 'wp_update_themes' );
remove_action( 'admin_init', '_maybe_update_themes' );
remove_action( 'wp_update_themes', 'wp_update_themes' );

remove_action( 'wp_maybe_auto_update', 'wp_maybe_auto_update' );
remove_action( 'init', 'wp_schedule_update_checks' );

/**
 * Reject cleartext requests to external hosts before a transport is selected.
 *
 * HTTPS requests continue through WordPress's normal HTTP stack, including
 * WP_HTTP_BLOCK_EXTERNAL and its exact WP_ACCESSIBLE_HOSTS allowlist. External
 * redirects are disabled separately below for every request, so no initial
 * URL can redirect inside the transport to cleartext HTTP or another host.
 * WordPress defines localhost and the site's own host as local, so their
 * direct loopback HTTP requests retain the documented exception.
 *
 * @param false|array|WP_Error $preempt     A preemptive HTTP response.
 * @param array                $parsed_args Parsed HTTP request arguments.
 * @param string               $url         Requested URL.
 * @return false|array|WP_Error
 */
function vpsfree_blog_require_https_for_external_http( $preempt, $parsed_args, $url ) {
	$parts = wp_parse_url( $url );

	if ( ! is_array( $parts ) || empty( $parts['scheme'] ) || empty( $parts['host'] ) ) {
		return new WP_Error(
			'vpsfree_http_url_invalid',
			'WordPress HTTP requests require an absolute URL with an explicit scheme and host.'
		);
	}

	if ( 'https' === strtolower( $parts['scheme'] ) ) {
		return $preempt;
	}

	$request_host = $parts['host'];
	$site_host    = wp_parse_url( get_option( 'siteurl' ), PHP_URL_HOST );
	$is_local     = 0 === strcasecmp( 'localhost', $request_host )
		|| ( is_string( $site_host ) && 0 === strcasecmp( $site_host, $request_host ) );

	if ( $is_local && 'http' === strtolower( $parts['scheme'] ) ) {
		return $preempt;
	}

	return new WP_Error(
		'vpsfree_external_https_required',
		'External WordPress HTTP requests must use HTTPS.'
	);
}
add_filter( 'pre_http_request', 'vpsfree_blog_require_https_for_external_http', 10, 3 );

/**
 * Disable redirects for every WordPress HTTP request.
 *
 * WordPress Requests follows redirects inside one transport request, where
 * pre_http_request and WP_HTTP_BLOCK_EXTERNAL are not guaranteed to run again
 * for every hop. Even an initially local or site-host request can redirect to
 * a cleartext or unapproved external target. No reviewed blog integration
 * requires redirects, so failing on every 3xx response is the narrowest safe
 * policy.
 *
 * @param array  $parsed_args Parsed HTTP request arguments.
 * @param string $url         Requested URL.
 * @return array
 */
function vpsfree_blog_disable_http_redirects( $parsed_args, $url ) {
	$parsed_args['redirection'] = 0;

	return $parsed_args;
}
add_filter( 'http_request_args', 'vpsfree_blog_disable_http_redirects', 10, 2 );
