package com.tobykurien.webapps.webviewclient

import android.app.AlertDialog
import android.content.DialogInterface
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.net.http.SslError
import android.util.Log
import android.view.View
import android.webkit.CookieSyncManager
import android.webkit.SslErrorHandler
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import com.tobykurien.webapps.activity.BaseWebAppActivity
import com.tobykurien.webapps.utils.Dependencies
import com.tobykurien.webapps.utils.Settings
import java.io.ByteArrayInputStream
import java.util.HashMap
import java.util.Set

class WebClient extends WebViewClient {
	package BaseWebAppActivity activity
	package WebView wv
	package View pd
	public Set<String> domainUrls
	package HashMap<String, Boolean> blockedHosts = new HashMap<String, Boolean>()

	new(BaseWebAppActivity activity, WebView wv, View pd, Set<String> domainUrls) {
		this.activity = activity
		this.wv = wv
		this.pd = pd
		this.domainUrls = domainUrls
	}

	override void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
		new AlertDialog.Builder(activity)
			.setTitle("Untrusted SSL Cert")
			.setMessage('''Issued by: «error.getCertificate().getIssuedBy().getDName()»
Issued to: «error.getCertificate().getIssuedTo().getDName()»
Expires: «error.getCertificate().getValidNotAfterDate().toLocaleString()»
''')
			.setPositiveButton("Add exception", [DialogInterface arg0, int arg1|
				handler.proceed()
			])
			.setNegativeButton("Cancel", [DialogInterface dialog, int which|
				handler.cancel()
			])
			.create()
			.show()
	}

	override void onPageFinished(WebView view, String url) {
		if(pd !== null) pd.setVisibility(View.GONE)
		activity.onPageLoadDone() // Google+ workaround to prevent opening of blank window
		wv.loadUrl("javascript:_window=function(url){ location.href=url; }")
		CookieSyncManager.getInstance().sync()
		super.onPageFinished(view, url)
	}

	override void onPageStarted(WebView view, String url, Bitmap favicon) {
		Log.d("webclient", '''loading «url»''')
		if(pd !== null) pd.setVisibility(View.VISIBLE)
		activity.onPageLoadStarted()
		super.onPageStarted(view, url, favicon)
	}

	override boolean shouldOverrideUrlLoading(WebView view, String url) {
		var Uri uri = getLoadUri(Uri.parse(url))
		if (!uri.getScheme().equals("https") || !isInSandbox(uri)) {
			var Intent i = new Intent(Intent.ACTION_VIEW)
			i.setData(uri)
			activity.startActivity(i)
			return true
		} else if (uri.getScheme().equals("mailto")) {
			var Intent i = new Intent(Intent.ACTION_SEND)
			i.putExtra(Intent.EXTRA_EMAIL, url)
			i.setType("text/html")
			activity.startActivity(i)
			return true
		} else if (uri.getScheme().equals("market")) {
			var Intent i = new Intent(Intent.ACTION_VIEW)
			i.setData(uri)
			i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			activity.startActivity(i)
			return true
		}
		return super.shouldOverrideUrlLoading(view, url)
	}

	override WebResourceResponse shouldInterceptRequest(WebView view, String url) {
		// Block 3rd party requests (i.e. scripts/iframes/etc. outside Google's domains)
		// and also any unencrypted connections
		var Uri uri = Uri.parse(url)
		var boolean isBlocked = false
		var Settings settings = Dependencies.getSettings(activity)
		if (settings.isBlock3rdParty() && !isInSandbox(uri)) {
			isBlocked = true
		}
		if (settings.isBlockHttp() && !uri.getScheme().equals("https")) {
			isBlocked = true
		}
		if (isBlocked) {
			// Log.d("webclient", "Blocking " + url);
			blockedHosts.put(getRootDomain(url), true)
			return new WebResourceResponse("text/plain", "utf-8", new ByteArrayInputStream("[blocked]".getBytes()))
		}
		return super.shouldInterceptRequest(view, url)
	}

	/** 
	 * Most blocked 3rd party domains are CDNs, so rather use root domain
	 * @param url
	 * @return
	 */
	def private String getRootDomain(String url) {
		var String host = Uri.parse(url).getHost()
		try {
			var String[] parts = host.split("\\.")
			if (parts.length > 1) {
				return '''«{val _rdIndx_parts=parts.length - 2 parts.get(_rdIndx_parts)}».«{val _rdIndx_parts=parts.length - 1 parts.get(_rdIndx_parts)}»'''
			} else {
				return host
			}
		} catch (Exception e) {
			// sometimes things don't quite work out
			return host
		}

	}

	override void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
		super.onReceivedError(view, errorCode, description, failingUrl)
		Toast.makeText(activity, description, Toast.LENGTH_LONG).show()
	}

	/** 
	 * Parse the Uri and return an actual Uri to load. This will handle
	 * exceptions, like loading a URL
	 * that is passed in the "url" parameter, to bypass click-throughs, etc.
	 * @param uri
	 * @return
	 */
	def protected Uri getLoadUri(Uri uri) {
		if(uri === null) return uri // handle google news links to external sites directly
		if (uri.getQueryParameter("url") !== null) {
			return Uri.parse(uri.getQueryParameter("url"))
		}
		return uri
	}

	/** 
	 * Returns true if the  linked site is within the Webapp's domain
	 * @param uri
	 * @return
	 */
	def protected boolean isInSandbox(Uri uri) {
		// String url = uri.toString();
		if("data".equals(uri.getScheme())) return true
		var String host = uri.getHost()
		for (String sites : domainUrls) {
			for (String site : sites.split(" ")) {
				if (site != null && host.toLowerCase().endsWith(site.toLowerCase())) {
					return true
				}

			}

		}
		return false
	}

	def Set<String> getBlockedHosts() {
		blockedHosts.keySet()
	}

	/** 
	 * Add domains to be unblocked
	 * @param unblock
	 */
	def void unblockDomains(Set<String> unblock) {
		for (String s : domainUrls) {
			unblock.add(s)
		}
		domainUrls = unblock
	}

}
