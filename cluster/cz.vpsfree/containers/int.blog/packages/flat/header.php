<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
	<meta charset="<?php bloginfo( 'charset' ); ?>" />
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
	<link rel="profile" href="http://gmpg.org/xfn/11" />
	<?php wp_head(); ?>
	<link rel="shortcut icon" href="https://blog.vpsfree.cz/wp-content/themes/flat/favicon.png" type="image/png" />
	<meta name="description" content="Blog spolku vpsFree.cz, o aktuálním dění na serverech, v serverovně i jinde."/>
	<meta name="keywords" content="blog,vps,vpsfree,server,linux,debian,ubuntu" />
	<meta name="robots" content="index, follow" />
	<meta name="author" content="vpsFree.cz"/>
	<meta name="theme-color" content="#16273f" />
	<link rel="apple-touch-icon" href="https://blog.vpsfree.cz/wp-content/themes/flat/ctverec.png" />
</head>

<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<div id="page">
	<div class="container">
		<div class="row row-offcanvas row-offcanvas-left">
			<div id="secondary" class="col-lg-3">
				<header id="masthead" class="site-header" role="banner">
					<div class="hgroup">
						<?php flat_logo(); ?>
					</div>
					<button type="button" class="btn btn-link hidden-lg toggle-sidebar" data-toggle="offcanvas" aria-label="Sidebar"><?php _e( '<i class="fa fa-gear"></i>', 'flat' ); ?></button>
					<button type="button" class="btn btn-link hidden-lg toggle-navigation" aria-label="Navigation Menu"><?php _e( '<i class="fa fa-bars"></i>', 'flat' ); ?></button>
					<nav id="site-navigation" class="navigation main-navigation" role="navigation">
						<?php wp_nav_menu( array( 'theme_location' => 'primary', 'menu_class' => 'nav-menu', 'container' => false ) ); ?>
					</nav>
				</header>

				<div class="sidebar-offcanvas">
					<?php get_sidebar(); ?>
				</div>
			</div>
			<div id="primary" class="content-area col-lg-9">
