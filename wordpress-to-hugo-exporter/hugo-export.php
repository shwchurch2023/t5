<?php

/*
Plugin Name: WordPress to Hugo Exporter
Description: Exports WordPress posts, pages, and options as YAML files parsable by Hugo
Version: 1.7
Author: Benjamin J. Balter
Author URI: http://ben.balter.com
License: GPLv3 or Later

Copyright 2012-2019  Benjamin J. Balter  (email : Ben@Balter.com)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, version 2, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

class Hugo_Export
{
    protected $_tempDir = null;

    // public $designated_exported_folder = null;
    // if set, the folder name for exported would be not generated randomly for better automation pipeline
    public $designated_exported_folder = 'wp-hugo-delta-processing';

    // if show verbose info
    public $is_verbose = true;

    // post_modified_gmt
    // public $only_process_changed_since = '1970-01-01';
    // must be in format: ****-**-**
    public $only_process_changed_since = '2003-01-01';

    // all patterns defined here will be replaces with $this->new_url_prefix
    public $url_prefixes_pattern_to_replace_with_new_prefix_from_content = array(
        '/https:\/\/.*?.shwchurch.org\//i',
        '/http:\/\/.*?.shwchurch.org\//i'
    );

    public $new_url_prefix = '/';

    // generated post descriptor file
    protected $post_descriptor_yaml = 'post-descriptor.yaml';

    // disable zipping when you don't want to transfer exported zip files
    protected $zip_disabled = true;

    // if only process changes on updated / added / deleted posts (delta processing)
    // for sake of processing speed, we could assign this to true
    // you must set zip_disabled to true if you want to use this feature
    protected $only_process_changes = false;
    

    protected $last_post_descriptor = array();
    protected $post_descriptor = array();
    
    private $zip_folder = 'hugo-export/'; //folder zip file extracts to
    private $post_folder = 'posts/'; //folder to place posts within

    /**
     * Manually edit this private property and set it to TRUE if you want to export
     * the comments as part of you posts. Pingbacks won't get exported.
     *
     * @var bool
     */
    private $include_comments = false; //export comments as part of the posts they're associated with

    public $rename_options = array('site', 'blog'); //strings to strip from option keys on export

    public $options = array( //array of wp_options value to convert to config.yaml
        'name',
        'description',
        'url'
    );

    public $required_classes = array(
        'spyc' => '%pwd%/includes/spyc.php',
        'Markdownify\Parser' => '%pwd%/includes/markdownify/Parser.php',
        'Markdownify\Converter' => '%pwd%/includes/markdownify/Converter.php',
        'Markdownify\ConverterExtra' => '%pwd%/includes/markdownify/ConverterExtra.php',
    );

    // time elapsed since last log, in seconds
    private $_log_time_elapsed = 0;
    private $_log_time_unixtime = 0;

    /**
     * Hook into WP Core
     */
    function __construct()
    {

        add_action('admin_menu', array(&$this, 'register_menu'));
        add_action('current_screen', array(&$this, 'callback'));
    }

    function log($log) {
        $this->_log_time_unixtime = $this->_log_time_unixtime ||  microtime(true);

        $now = microtime(true);

        $this->_log_time_elapsed = $now - $this->_log_time_unixtime;

        $this->_log_time_unixtime  = $now;

        if ($this->is_verbose) {
            echo "[LOG] $log; Time elapsed: " . date('H:i:s',$this->_log_time_elapsed);
        }
    }

    /**
     * Listens for page callback, intercepts and runs export
     */
    function callback()
    {

        if (get_current_screen()->id != 'export')
            return;

        if (!isset($_GET['type']) || $_GET['type'] != 'hugo')
            return;

        if (!current_user_can('manage_options'))
            return;

        $this->export();
        exit();
    }

    /**
     * Add menu option to tools list
     */
    function register_menu()
    {

        add_management_page(__('Export to Hugo', 'hugo-export'), __('Export to Hugo', 'hugo-export'), 'manage_options', 'export.php?type=hugo');
    }

    /** 
     * Get content with no url prefixes in $this->url_prefixes_pattern_to_replace_with_new_prefix_from_content and WP_SITEURL
     */
    function get_content_with_no_unwanted_url_prefixes($post_content) {

        $url_patterns = $this->url_prefixes_pattern_to_replace_with_new_prefix_from_content;
        $post_content = preg_replace($url_patterns, $this->new_url_prefix, $post_content);

        if (defined('WP_SITEURL') && WP_SITEURL) {
            echo "[INFO] Replace WP_SITEURL with $this->new_url_prefix";
            $post_content = str_replace(WP_SITEURL, $this->new_url_prefix, $post_content);
        }

        return $post_content;

    }

    /**
     * Get an array of all post and page IDs
     * Note: We don't use core's get_posts as it doesn't scale as well on large sites
     */
    function get_posts()
    {

        echo "[INFO] Getting Posts that's changed since $this->only_process_changed_since";

        global $wpdb;
        return $wpdb->get_col("SELECT ID FROM $wpdb->posts WHERE post_status in ('publish', 'draft', 'private') AND post_type IN ('post', 'page' ) AND post_modified_gmt > STR_TO_DATE('$this->only_process_changed_since', '%Y-%m-%d');");
        // return $wpdb->get_col("SELECT ID FROM $wpdb->posts WHERE post_status in ('publish', 'draft', 'private') AND post_type IN ('post', 'page' )");
    }

    /**
     * @param WP_Post $post
     * @param bool $isUpdatedDate - Is get updated date
     *
     * @return bool|string
     */
    protected function _getPostDateAsIso(WP_Post $post, $isUpdatedDate)
    {
        // Dates in the m/d/y or d-m-y formats are disambiguated by looking at the separator between the various components: if the separator is a slash (/),
        // then the American m/d/y is assumed; whereas if the separator is a dash (-) or a dot (.), then the European d-m-y format is assumed.
        if ($isUpdatedDate) {
            $unixTime = strtotime($post->post_modified_gmt);
        } else {
            $unixTime = strtotime($post->post_date_gmt);
        }
        
        return date('c', $unixTime);
    }

    /**
     * Convert a posts meta data (both post_meta and the fields in wp_posts) to key value pairs for export
     */
    function convert_meta(WP_Post $post)
    {
        $output = array(
            'title' => html_entity_decode(get_the_title($post), ENT_QUOTES | ENT_XML1, 'UTF-8'),
            'author' => get_userdata($post->post_author)->display_name,
            'type' => get_post_type($post),
            'date' => $this->_getPostDateAsIso($post, false),
            'lastmod' => $this->_getPostDateAsIso($post, true),
        );
        if (false === empty($post->post_excerpt)) {
            $output['excerpt'] = $post->post_excerpt;
        }

        if (in_array($post->post_status, array('draft', 'private'))) {
            // Mark private posts as drafts as well, so they don't get
            // inadvertently published.
            $output['draft'] = true;
        }
        if ($post->post_status == 'private') {
            // hugo doesn't have the concept 'private posts' - this is just to
            // disambiguate between private posts and drafts.
            $output['private'] = true;
        }

        //turns permalink into 'url' format, since Hugo supports redirection on per-post basis
        if ('page' !== $post->post_type) {
            $output['url'] = urldecode(str_replace(home_url(), '', get_permalink($post)));
        }

        // check if the post or page has a Featured Image assigned to it.
        if (has_post_thumbnail($post)) {
            $output['featured_image'] = str_replace(get_site_url(), "", get_the_post_thumbnail_url($post));
        }

        //convert traditional post_meta values, hide hidden values
        foreach (get_post_custom($post->ID) as $key => $value) {
            if (substr($key, 0, 1) == '_') {
                continue;
            }
            if (false === $this->_isEmpty($value)) {
                $output[$key] = $value;
            }
        }
        return $output;
    }

    protected function _isEmpty($value)
    {
        if (true === is_array($value)) {
            if (true === empty($value)) {
                return true;
            }
            if (1 === count($value) && true === empty($value[0])) {
                return true;
            }
            return false;
//            $isEmpty=true;
//            foreach($value as $k=>$v){
//                if(true === empty($v)){
//                    $isEmpty
//                }
//            }
//            return $isEmpty;
        }
        return true === empty($value);
    }

    /**
     * Convert post taxonomies for export
     */
    function convert_terms($post)
    {

        $output = array();
        foreach (get_taxonomies(array('object_type' => array(get_post_type($post)))) as $tax) {

            $terms = wp_get_post_terms($post, $tax);

            //convert tax name for Hugo
            switch ($tax) {
                case 'post_tag':
                    $tax = 'tags';
                    break;
                case 'category':
                    $tax = 'categories';
                    break;
            }

            if ($tax == 'post_format') {
                $output['format'] = get_post_format($post);
            } else {
                $output[$tax] = wp_list_pluck($terms, 'name');
            }
        }

        return $output;
    }

    /**
     * Convert the main post content to Markdown.
     */
    function convert_content($post)
    {
        $content = apply_filters('the_content', $post->post_content);
        $converter = new Markdownify\ConverterExtra;
        $markdown = $converter->parseString($content);

        if (false !== strpos($markdown, '[]: ')) {
            // faulty links; return plain HTML
            return $content;
        }

        return $markdown;
    }

    /**
     * Loop through and convert all comments for the specified post
     */
    function convert_comments($post)
    {
        $args = array(
            'post_id' => $post->ID,
            'order' => 'ASC',   // oldest comments first
            'type' => 'comment' // we don't want pingbacks etc.
        );
        $comments = get_comments($args);
        if (empty($comments)) {
            return '';
        }

        $converter = new Markdownify\ConverterExtra;
        $output = "\n\n## Comments";
        foreach ($comments as $comment) {
            $content = apply_filters('comment_text', $comment->comment_content);
            $output .= "\n\n### Comment by " . $comment->comment_author . " on " . get_comment_date("Y-m-d H:i:s O", $comment) . "\n";
            $output .= $converter->parseString($content);
        }

        return $output;
    }

    /**
     * Get all post metadata of name / created-date / updated-date, etc
     * 
     * @description
     * 
     * Get post metadata for delta (diff) processing.
     * 
     * - For meta website, you may not want to get all posts everytime which is pretty slow.
     * - This will generate a descriptor for comparing with last time's operations
     * 
     * 
     */ 
    function set_post_descriptor($postDescriptorMeta) {
        $this->post_descriptor = $postDescriptorMeta;
    }

    /** 
     * Load yaml file saved last time to variable $this->last_post_descriptor
    */
    function load_yaml_to_last_post_descriptor() {
        $fileFullPath = $this->get_post_descriptor_full_path();
        if (file_exists($fileFullPath)) {
            $this->last_post_descriptor = yaml_parse_file($this->get_post_descriptor_full_path());
        }

    }

    function save_post_descriptor() {  
        $this->log("[INFO] Saving Post descriptor"); 
        $this->write(yaml_emit($this->post_descriptor), $this->post_descriptor_yaml, 'plain');
        $this->log("[INFO] Saved Post descriptor"); 
    }

    function get_post_descriptor_full_path() {
        return $this->dir . $this->post_descriptor_yaml;
    }
    
    function is_file_metadata_changed($fileId){
        return $this->post_descriptor[$fileId] !== $this->last_post_descriptor[$fileId];
    }

    /**
     * Loop through and convert all posts to MD files with YAML headers
     * 
     * @param bool $isGenerateMetaData - If just generate Page metadata
     * useful to decide if skip unchanges posts for mega website (delta processing)
     */
    function convert_posts($isGenerateMetaData)
    {
        global $post;

        $postDescriptorMeta = array();

        if ($isGenerateMetaData) {
            $this->log("[INFO] Post MetatData generating"); 
        } else {
            $this->log("[INFO] Post generating"); 
        }

        foreach ($this->get_posts() as $postID) {
            $post = get_post($postID);
            setup_postdata($post);
            $meta = array_merge($this->convert_meta($post), $this->convert_terms($postID));
            // remove falsy values, which just add clutter
            foreach ($meta as $key => $value) {
                if (!is_numeric($value) && !$value) {
                    unset($meta[$key]);
                }
            }

            if ($isGenerateMetaData) {
                array_push($postDescriptorMeta, array('post_id_' . $postID => implode($meta)));
                contine;
            }

            if ($this->only_process_changes && !$this->is_file_metadata_changed($postID)) {
                contine;
            }

            // Hugo doesn't like word-wrapped permalinks
            $output = Spyc::YAMLDump($meta, false, 0);

            $output .= "\n---\n";
            $output .= $this->convert_content($post);
            if ($this->include_comments) {
                $output .= $this->convert_comments($post);
            }
            $output = $this->get_content_with_no_unwanted_url_prefixes($output);
            $this->write($output, $post, 'post');
        }

        if ($isGenerateMetaData) {
            $this->set_post_descriptor($postDescriptorMeta);
        }

        if ($isGenerateMetaData) {
            $this->log("[INFO] Post MetatData generated"); 
        } else {
            $this->log("[INFO] Post generated"); 
        }
        
    }

    function filesystem_method_filter()
    {
        return 'direct';
    }

    /**
     *  Conditionally Include required classes
     */
    function require_classes()
    {

        foreach ($this->required_classes as $class => $path) {
            if (class_exists($class)) {
                continue;
            }
            $path = str_replace("%pwd%", dirname(__FILE__), $path);
            require_once($path);
        }
    }

    /**
     * Main function, bootstraps, converts, and cleans up
     */
    function export()
    {
        $this->log("[INFO][START] Exported.");
        global $wp_filesystem;

        define('DOING_JEKYLL_EXPORT', true);

        $this->require_classes();

        add_filter('filesystem_method', array(&$this, 'filesystem_method_filter'));

        WP_Filesystem();

        $this->prepare_variables();
        $this->set_exported_folder();

        $wp_filesystem->mkdir($this->dir);
        $wp_filesystem->mkdir($this->dir . $this->post_folder);
        $wp_filesystem->mkdir($this->dir . 'wp-content/');

        $this->convert_options();
        $this->convert_posts(false);
        $this->convert_uploads();

        if ( !$this->zip_disabled ){
            
            $this->zip();
            $this->send();
            $this->cleanup();
        }

        if ($this->zip_disabled) {
            echo "[INFO] Exported, check it out your tmp folder $this->dir";
        }

        if ($this->only_process_changes) {
            $this->save_post_descriptor();
        }

        $this->log("[INFO][END] Exported.");
        
    }
    
    /** 
     * Prepare variables before export
    */
    function prepare_variables() {
        if ($this->only_process_changes && ! $this->zip_disabled) {
            echo "[WARN] only_process_changes toggle only works when zip_disabled is set to true";
            $this->only_process_changes = false;
        }

        if ($this->only_process_changes) {
            $this->load_yaml_to_last_post_descriptor();
            $this->convert_posts(true);
        }
        
    }

    function set_exported_folder() {
        $tmpFolder = $this->getTempDir();
        $filePrefix = 'wp-hugo';

        if ($this->designated_exported_folder) {
            $this->dir = $tmpFolder . '/' . $this->designated_exported_folder . '/';
        } else {
            $this->dir = $tmpFolder . '/'.  $filePrefix . '-' . md5(time()) . '/';
        }
        
        $this->zip = $tmpFolder . $filePrefix . '.zip';

        if ($this->only_process_changes) {
            $this->dir = $tmpFolder . $filePrefix . '-delta-processing/';
        }
    }

    /**
     * Convert options table to config.yaml file
     */
    function convert_options()
    {

        global $wp_filesystem;

        $this->log("[INFO] Converting Global Options to HUGO config"); 

        $options = wp_load_alloptions();
        foreach ($options as $key => &$option) {

            if (substr($key, 0, 1) == '_')
                unset($options[$key]);

            //strip site and blog from key names, since it will become site. when in Hugo
            foreach ($this->rename_options as $rename) {

                $len = strlen($rename);
                if (substr($key, 0, $len) != $rename)
                    continue;

                $this->rename_key($options, $key, substr($key, $len));
            }

            $option = maybe_unserialize($option);
        }

        foreach ($options as $key => $value) {

            if (!in_array($key, $this->options))
                unset($options[$key]);
        }

        $output = Spyc::YAMLDump($options);

        //strip starting "---"
        $output = substr($output, 4);

        $wp_filesystem->put_contents($this->dir . 'config.yaml', $output);

        $this->log("[INFO] Converted Global Options to HUGO config"); 
        
    }

    /**
     * Write string buffer to file in temp dir
     * 
     * @param string $content - String to write to disk
     * @param mixed $context - Dynamic Object for processing
     *                          When is a $contextType is plain, it should be a file name 
     *                          which to be write to $this->dir
     * @param string $contextType - Describe $context. 
     *                              Possible values: 
     *                                  'post' - Wordpress Post Object; Defaulted if omitted
     *                                  'plain' - Plain string
     */
    function write($content, $context, $contextType)
    {

        global $wp_filesystem;

        $contextTypeEnum = array(
            'POST' => 'post',
            'PLAIN' => 'plain'
        );

        $isPost = empty($contextType) || $contextType === $contextTypeEnum['POST'];
        $isPlainFile = $contextType === $contextTypeEnum['PLAIN'];

        if ($isPost) {

            $post = $context;
           
            if (get_post_type($post) == 'page') {
                $wp_filesystem->mkdir(urldecode($this->dir . $post->post_name));
                $filename = urldecode($post->post_name . '/index.md');
            } else {
                $filename = $this->post_folder . date('Y-m-d', strtotime($post->post_date)) . '-' . urldecode($post->post_name) . '.md';
            }
            
        } else if ($isPlainFile) {
            $filename = $context;
        }

        $this->log("[INFO] Writing content to $this->dir/$filename");

        $wp_filesystem->put_contents($this->dir . $filename, $content);
    }

    /**
     * Zip temp dir
     */
    function zip()
    {

        $this->log("[INFO] Zipping"); 
        //create zip
        $zip = new ZipArchive();
        $err = $zip->open($this->zip, ZIPARCHIVE::CREATE | ZIPARCHIVE::OVERWRITE);
        if ($err !== true) {
            die("Failed to create '$this->zip' err: $err");
        }
        $this->_zip($this->dir, $zip);
        $zip->close();

        $this->log("[INFO] Zipped"); 
    }

    /**
     * Helper function to add a file to the zip
     */
    function _zip($dir, &$zip)
    {

        //loop through all files in directory
        foreach ((array)glob(trailingslashit($dir) . '*') as $path) {

            // periodically flush the zipfile to avoid OOM errors
            if ((($zip->numFiles + 1) % 250) == 0) {
                $filename = $zip->filename;
                $zip->close();
                $zip->open($filename);
            }

            if (is_dir($path)) {
                $this->_zip($path, $zip);
                continue;
            }

            //make path within zip relative to zip base, not server root
            $local_path = str_replace($this->dir, $this->zip_folder, $path);

            //add file
            $zip->addFile(realpath($path), $local_path);
        }
    }

    /**
     * Send headers and zip file to user
     */
    function send()
    {
        $this->log("[INFO] Send headers and zip file to user"); 
        if ('cli' === php_sapi_name()) {
            echo "\nThis is your file!\n$this->zip\n";
            return null;
        }

        //send headers
        @header('Content-Type: application/zip');
        @header("Content-Disposition: attachment; filename=hugo-export.zip");
        @header('Content-Length: ' . filesize($this->zip));

        //read file
        ob_clean();
        flush();
        readfile($this->zip);
        $this->log("[INFO] Sent headers and zip file to user"); 
    }

    /**
     * Clear temp files
     */
    function cleanup()
    {
        $this->log("[INFO] Clearing temp files"); 
        global $wp_filesystem;
        $wp_filesystem->delete($this->dir, true);
        if ('cli' !== php_sapi_name()) {
            $wp_filesystem->delete($this->zip);
        }
        $this->log("[INFO] Cleared temp files"); 
    }

    /**
     * Rename an assoc. array's key without changing the order
     */
    function rename_key(&$array, $from, $to)
    {

        $keys = array_keys($array);
        $index = array_search($from, $keys);

        if ($index === false)
            return;

        $keys[$index] = $to;
        $array = array_combine($keys, $array);
    }

    function convert_uploads()
    {

        $upload_dir = wp_upload_dir();
        $this->log("[INFO] Converting all uploads from $upload_dir"); 
        $this->copy_recursive($upload_dir['basedir'], $this->dir . str_replace(trailingslashit(get_home_url()), '', $upload_dir['baseurl']));
        $this->log("[INFO] Converting all uploads from $upload_dir"); 
    }

    /**
     * Copy a file, or recursively copy a folder and its contents
     *
     * @author      Aidan Lister <aidan@php.net>
     * @version     1.0.1
     * @link        http://aidanlister.com/2004/04/recursively-copying-directories-in-php/
     *
     * @param       string $source Source path
     * @param       string $dest Destination path
     *
     * @return      bool     Returns TRUE on success, FALSE on failure
     */
    function copy_recursive($source, $dest)
    {

        global $wp_filesystem;

        // Check for symlinks
        if (is_link($source)) {
            return symlink(readlink($source), $dest);
        }

        // Simple copy for a file
        if (is_file($source)) {
            return $wp_filesystem->copy($source, $dest);
        }

        // Make destination directory
        if (!is_dir($dest)) {
            if (!wp_mkdir_p($dest)) {
                $wp_filesystem->mkdir($dest) or wp_die("Could not created $dest");
            }
        }

        // Loop through the folder
        $dir = dir($source);
        while (false !== $entry = $dir->read()) {
            // Skip pointers
            if ($entry == '.' || $entry == '..') {
                continue;
            }

            // Deep copy directories
            $this->copy_recursive("$source/$entry", "$dest/$entry");
        }

        // Clean up
        $dir->close();
        return true;
    }

    /**
     * @param null $tempDir
     */
    public function setTempDir($tempDir)
    {
        
        $this->_tempDir = $tempDir . (false === strpos($tempDir, DIRECTORY_SEPARATOR) ? DIRECTORY_SEPARATOR : '');
        $this->log("[INFO] Set _tempDir to $this->_tempDir");
    }

    /**
     * @return null
     */
    public function getTempDir()
    {
        if (null === $this->_tempDir) {
            $this->_tempDir = get_temp_dir();
        }
        return $this->_tempDir;
    }
}

$je = new Hugo_Export();

if (defined('WP_CLI') && WP_CLI) {

    class Hugo_Export_Command extends WP_CLI_Command
    {

        function __invoke()
        {
            global $je;

            $je->export();
        }
    }

    WP_CLI::add_command('hugo-export', 'Hugo_Export_Command');
}

