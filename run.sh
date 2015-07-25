#/bin/bash
set -e

export FAILED=false
export APT_GET_UPDATED=false

# set amount of threads if not set
CORES=`nproc`
echo "$CORES cores detected"
if [ ! -n "$WERCKER_MINIFY_THREADS" ]; then
    export WERCKER_MINIFY_THREADS=$CORES
fi
echo "running with $WERCKER_MINIFY_THREADS threads"

# set base directory to public if not set
DEFAULTDIR="public"
if [ ! -n "$WERCKER_MINIFY_BASEDIR" ]; then
    export WERCKER_MINIFY_BASEDIR=$DEFAULTDIR
fi

# set minify defaults
if [ ! -n "$WERCKER_MINIFY_HTML" ]; then
    export WERCKER_MINIFY_HTML=true
fi
if [ ! -n "$WERCKER_MINIFY_CSS" ]; then
    export WERCKER_MINIFY_CSS=true
fi
if [ ! -n "$WERCKER_MINIFY_JS" ]; then
    export WERCKER_MINIFY_JS=true
fi

# set arguments if not set
DEFAULTARGS="--use-short-doctype --remove-style-link-type-attributes --remove-script-type-attributes --remove-comments --minify-css --minify-js --collapse-whitespace --remove-comments-from-cdata --conservative-collapse --remove-cdatasections-from-cdata"
if [ ! -n "$WERCKER_MINIFY_HTMLARGS" ]; then
    export WERCKER_MINIFY_HTMLARGS="$DEFAULTARGS"
fi

if [ ! -n "$WERCKER_MINIFY_YUIARGS" ]; then
    export WERCKER_MINIFY_YUIARGS=""
fi

minifyHTML()
{
    # minify all the HTML files
    echo "minifying HTML files in $WERCKER_MINIFY_BASEDIR with arguments $WERCKER_MINIFY_HTMLARGS"
    
    find ${WERCKER_MINIFY_BASEDIR} -iname *.html -print0 | xargs -0 -t -P ${WERCKER_MINIFY_THREADS} -n 1 -I filename html-minifier ${WERCKER_MINIFY_HTMLARGS} -o filename filename
}

minifyCSS()
{
    # minify all the CSS files
    echo "minifying CSS files in $WERCKER_MINIFY_BASEDIR with arguments $WERCKER_MINIFY_YUIARGS"
    
    find ${WERCKER_MINIFY_BASEDIR} -iname *.css -print0 | xargs -0 -t -n 1 -P ${WERCKER_MINIFY_THREADS} -I filename ${YUI_COMMAND} ${WERCKER_MINIFY_YUIARGS} -o filename filename
}

minifyJS()
{
    # minify all the JS files
    echo "minifying JS files in $WERCKER_MINIFY_BASEDIR with arguments $WERCKER_MINIFY_YUIARGS"
    
    find ${WERCKER_MINIFY_BASEDIR} -iname *.js -print0 | xargs -0 -t -n 1 -P ${WERCKER_MINIFY_THREADS} -I filename ${YUI_COMMAND} ${WERCKER_MINIFY_YUIARGS} -o filename filename
}

verifyJava()
{
    # check if java is installed
    if [ "$(which java)" == "" ]; then
        echo "java not installed, installing..."
        if [ "$(which apt-get)" != "" ]; then
            
            if [ "$APT_GET_UPDATED" = false ] ; then
                apt-get update
                export APT_GET_UPDATED=true
            fi            
                
            apt-get install -y openjdk-7-jre
        else
            yum install -y java-1.7.0-openjdk
        fi
    fi
}

verifyCurl()
{
    # check if curl is installed
    if [ "$(which curl)" == "" ]; then
        echo "curl not installed, installing..."
        if [ "$(which apt-get)" != "" ]; then
            
            if [ "$APT_GET_UPDATED" = false ] ; then
                apt-get update
                export APT_GET_UPDATED=true
            fi            
            
            apt-get install -y curl
        else
            yum install -y curl
        fi
    fi
}

verifyNode()
{
    # check if node is installed
    if [ "$(which node)" == "" ]; then
    
        verifyCurl
    
        # install node
        echo "node not installed, installing..."
        if [ "$(which apt-get)" != "" ]; then
    		curl --silent --location https://deb.nodesource.com/setup_0.12 | bash -
            export APT_GET_UPDATED=true
            apt-get install -y npm nodejs build-essential
        else
            curl --silent --location https://rpm.nodesource.com/setup | bash -
            yum install -y nodejs npm gcc-c++ make
        fi
    fi
}

doHTML()
{
    verifyNode
    
    # install the HTML minifier
    echo "installing html-minifier with npm"
    npm install html-minifier -g
    
    # verify HTML minifier installation
    if [ "$(which html-minifier)" == "" ]; then
        echo "html-minifier installation failed, not minifying HTML"
        export FAILED=true
    else
        minifyHTML
    fi
}

doCSSJS()
{
    verifyJava
    
    # install yui-compressor
    echo "installing yui-compressor with npm"
    npm install yui-compressor -g
    
    # verify yui-compressor installation
    if [ "$(which yui-compressor)" == "" ]; then
        echo "yui-compressor installation failed, retrying with a jar file..."
        
        verifyCurl
        
        curl -L https://github.com/yui/yuicompressor/releases/download/v2.4.8/yuicompressor-2.4.8.jar -o yui.jar
        export YUI_COMMAND="java -jar yui.jar"
        
        if [ "$WERCKER_MINIFY_CSS" != "false" ]; then
            minifyCSS
        fi
        if [ "$WERCKER_MINIFY_JS" != "false" ]; then
            minifyJS
        fi
        
    else
        export YUI_COMMAND="yui-compressor"
        
        if [ "$WERCKER_MINIFY_CSS" != "false" ]; then
            minifyCSS
        fi
        if [ "$WERCKER_MINIFY_JS" != "false" ]; then
            minifyJS
        fi
        
    fi
}

if [ "$WERCKER_MINIFY_HTML" != "false" ]; then
    doHTML
fi

if [ "$WERCKER_MINIFY_CSS" != "false" ] || [ "$WERCKER_MINIFY_JS" != "false" ] ; then
    doCSSJS
fi

if [ "$FAILED" = true ] ; then
    echo "Not all tasks were succesfully completed."
    exit 1
fi
