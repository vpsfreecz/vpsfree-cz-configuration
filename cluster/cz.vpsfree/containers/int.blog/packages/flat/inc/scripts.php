<?php
function flat_scripts_styles() {
	$version = '1.4.2';

	if ( is_singular() && comments_open() && get_option( 'thread_comments' ) )
		wp_enqueue_script( 'comment-reply' );

	wp_enqueue_style( 'flat-main', get_template_directory_uri() . '/assets/css/main.min.css', array(), $version );
	wp_enqueue_style( 'flat-style', get_stylesheet_uri(), array(), $version );
	wp_enqueue_script( 'flat-bootstrap', get_template_directory_uri() . '/assets/js/bootstrap-3.4.1.min.js', array( 'jquery' ), '3.4.1', true );
	wp_enqueue_script( 'flat-theme', get_template_directory_uri() . '/assets/js/theme.js', array( 'jquery', 'flat-bootstrap' ), $version, true );
}
add_action( 'wp_enqueue_scripts', 'flat_scripts_styles' );

function flat_ie_support_header() {
		echo '<!--[if lt IE 9]>'. "\n";
		echo '<script src="' . esc_url( get_template_directory_uri() . '/assets/js/html5shiv.min.js' ) . '"></script>'. "\n";
		echo '<script src="' . esc_url( get_template_directory_uri() . '/assets/js/respond.min.js' ) . '"></script>'. "\n";
		echo '<![endif]-->'. "\n";
}
add_action( 'wp_head', 'flat_ie_support_header' );
