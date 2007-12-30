<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output
	encoding="UTF-8"
/>

<xsl:include href="misc.xsl"/>

<xsl:template match="/page">
	<html>
		<head>
			<title>
				<xsl:value-of select="manifest/title/text()"/>
			</title>
			<link rel="stylesheet" type="text/css" href="/css/main.css" />
			<link rel="stylesheet" type="text/css" href="/adm/css/admin.css" />
			<script type="text/javascript" src="/adm/js/admin.js"></script>
			<link rel="shortcut icon" href="/favicon.ico" type="image/x-icon" />		

			<xsl:if test="
				manifest/uri/text() = '/adm/add/' or 
				starts-with (manifest/uri/text(), '/adm/preview/') or 
				(starts-with (manifest/uri/text(), '/adm/edit/') and manifest/uri/text() != '/adm/edit/')
				">
			</xsl:if>
		</head>
		<body>
			<div id="language-selector" style="line-height: 150%">
				<a href="/">Test site</a>
			</div>
			<div class="top">
				<xsl:value-of select="manifest/title/text()"/>
			</div>
			<xsl:apply-templates select="content"/>
		</body>
	</html>
</xsl:template>

<xsl:template match="/page/content">
	<div class="content">
		<xsl:call-template name="selector"/>
		<xsl:apply-templates/>
	</div>
</xsl:template>

<xsl:template name="selector">
	<div class="selector">
		<xsl:choose>
			<xsl:when test="/page/manifest/uri/text() != '/adm/add/'">
				<a href="/adm/add/">New article</a>
			</xsl:when>
			<xsl:otherwise>
				<span>New article</span>
			</xsl:otherwise>
		</xsl:choose>
		<xsl:text>&#8194; </xsl:text>
		<xsl:choose>
			<xsl:when test="/page/manifest/uri/text() = '/adm/edit/'">
				<span>Edit</span>
			</xsl:when>
			<xsl:when test="starts-with (/page/manifest/uri/text(), '/adm/edit/')">
				<span>
					<a href="/adm/edit/">Edit</a>
				</span>
			</xsl:when>
			<xsl:otherwise>
				<a href="/adm/edit/">Edit</a>
			</xsl:otherwise>
		</xsl:choose>

		<xsl:if test="/page/manifest/user/text() = 'main'">
			<xsl:text>&#8194; </xsl:text>
			<xsl:choose>
				<xsl:when test="/page/manifest/uri/text() = '/adm/users/'">
					<span>Users</span>
				</xsl:when>
				<xsl:otherwise>
					<a href="/adm/users/">Users</a>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
	</div>
</xsl:template>

<xsl:template match="content/add-new">
	<xsl:call-template name="add-or-edit-form"/>
</xsl:template>

<xsl:template match="content/edit-message">
	<xsl:choose>
		<xsl:when test="starts-with (/page/manifest/uri/text(), '/adm/preview/')">
			<xsl:call-template name="preview-message"/>
			<xsl:call-template name="add-or-edit-form"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:call-template name="add-or-edit-form"/>
			<br />
			<div class="separator"></div>
			<xsl:call-template name="preview-message"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="content/message-list">
	<xsl:apply-templates select="item[@site_id = 1]"/>
</xsl:template>

<xsl:template match="content/message-list/item">
	<p style="margin: 0.3em 0 1em 0">
		<xsl:variable name="colour">
			<xsl:choose>
				<xsl:when test="@is_published = 1 and @is_visible = 0">#2493F1</xsl:when>
				<xsl:when test="@is_published = 1">green</xsl:when>
				<xsl:otherwise>red</xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<a href="/adm/edit/{@id}/" style="color: {$colour}">
			<xsl:value-of select="text()" disable-output-escaping="yes"/>
		</a>
		<br />
		<span class="published">
			<xsl:if test="@day &lt; 10">0</xsl:if>
			<xsl:value-of select="@day"/>
			<xsl:text>.</xsl:text>
			<xsl:if test="@month &lt; 10">0</xsl:if>
			<xsl:value-of select="@month"/>
			<xsl:text>.</xsl:text>
			<xsl:value-of select="@year"/>
			<xsl:text>, </xsl:text>
			<xsl:if test="@hour &lt; 10">0</xsl:if>
			<xsl:value-of select="@hour"/>
			<xsl:text>:</xsl:text>
			<xsl:if test="@minute &lt; 10">0</xsl:if>
			<xsl:value-of select="@minute"/>
		</span>
	</p>
</xsl:template>

<xsl:template name="add-or-edit-form">
	<xsl:if test="/page/content/edit-message/modified/text()">
		<div class="modified">
			<xsl:text>Last modified by </xsl:text>
			<xsl:value-of select="/page/content/edit-message/modified/text()"/>
			<xsl:text> on </xsl:text>
			<xsl:call-template name="month-name">
				<xsl:with-param name="month" select="/page/content/edit-message/modified/@month"/>
			</xsl:call-template>
			<xsl:text> </xsl:text>
			<xsl:value-of select="/page/content/edit-message/modified/@day"/>
			<xsl:text>, </xsl:text>
			<xsl:value-of select="/page/content/edit-message/modified/@year"/>
			<xsl:text> at </xsl:text>
			<xsl:value-of select="/page/content/edit-message/modified/@hour"/>
			<xsl:text>:</xsl:text>
			<xsl:value-of select="/page/content/edit-message/modified/@minute"/>
		</div>
	</xsl:if>

	<form method="post">
		<table width="90%">
			<tr>
				<td class="label">Title</td>
				<td width="90%">
					<input type="text" name="title" class="text" id="TitleField" onkeyup="TestEmptiness()" value="{/page/content/edit-message/title/text()}" />
				</td>
			</tr>
			<tr>
				<td class="label">URI</td>
				<td>
					<input type="text" name="uri" class="narrow" value="{/page/content/edit-message/title/@uri}" />
				</td>
			</tr>
			<tr>
				<td colspan="2">	
					<xsl:text>Text</xsl:text>
					<br />
					<textarea name="ContentField" id="ContentField" style="height: 800px" onkeyup="TestEmptiness()">
						<xsl:copy-of select="/page/content/edit-message/content/text() | /page/content/edit-message/content/*"/>
					</textarea>
				</td>
			</tr>
			<tr>
				<td class="label">Keywords (tags)</td>
				<td>
					<input type="text" name="keywords" id="Keywords" class="text">
						<xsl:attribute name="value">
							<xsl:for-each select="/page/content/edit-message/keywords/item">
								<xsl:value-of select="@uri"/>
								<xsl:if test="position() != last()">
									<xsl:text>, </xsl:text>
								</xsl:if>
							</xsl:for-each>
						</xsl:attribute>
					</input>
					<div class="comment">
						<i>separated by comma:</i>
					</div>
					<div class="comment spare">
						<xsl:for-each select="/page/manifest/keyword-list/item">
							<span class="nobr">
								<span class="add-keyword" onclick="AddKeyword('{@uri}')">
									<xsl:value-of select="text()" disable-output-escaping="yes"/>
								</span>
								<xsl:text> </xsl:text>
								<xsl:value-of select="@uri"/>
								<xsl:if test="position() != last()">
									<xsl:text>,</xsl:text>
								</xsl:if>
							</span>
							<xsl:if test="position() != last()">
								<xsl:text> </xsl:text>
							</xsl:if>
						</xsl:for-each>
					</div>
				</td>
			</tr>
			<xsl:if test="starts-with (/page/manifest/uri/text(), '/adm/edit/') or starts-with (/page/manifest/uri/text(), '/adm/preview/')">
				<tr>
					<td>
					</td>
					<td>
						<br />
						<input type="checkbox" name="is_published" value="yes" id="IsPublished">
							<xsl:if test="/page/content/edit-message/title/@is_published = '1'">
								<xsl:attribute name="checked">checked</xsl:attribute>
							</xsl:if>
						</input>
						<label for="IsPublished"> published</label>
						<xsl:text> &#160; </xsl:text>
						<select name="day" id="SelectDay">
							<xsl:call-template name="list-option">
								<xsl:with-param name="curr" select="1"/>
								<xsl:with-param name="max" select="31"/>
								<xsl:with-param name="sel" select="/page/content/edit-message/title/@day"/>
							</xsl:call-template>
						</select>
						<xsl:text> </xsl:text>
						<select name="month" id="SelectMonth">
							<xsl:call-template name="month-option">
								<xsl:with-param name="curr" select="1"/>
								<xsl:with-param name="month" select="/page/content/edit-message/title/@month"/>
							</xsl:call-template>
						</select>
						<xsl:text> </xsl:text>
						<input type="text" size="4" name="year" id="SelectYear" value="{/page/content/edit-message/title/@year}" />
						<xsl:text>,&#160;&#160;</xsl:text>
						<select name="hour" id="SelectHour">
							<xsl:call-template name="list-option">
								<xsl:with-param name="curr" select="0"/>
								<xsl:with-param name="max" select="23"/>
								<xsl:with-param name="sel" select="/page/content/edit-message/title/@hour"/>
								<xsl:with-param name="zero" select="'true'"/>
							</xsl:call-template>
						</select>
						<xsl:text>:</xsl:text>
						<select name="minute" id="SelectMinute">
							<xsl:call-template name="list-option">
								<xsl:with-param name="curr" select="0"/>
								<xsl:with-param name="max" select="59"/>
								<xsl:with-param name="sel" select="/page/content/edit-message/title/@minute"/>
								<xsl:with-param name="zero" select="'true'"/>
							</xsl:call-template>
						</select>
						<xsl:text>&#160;&#160; </xsl:text>
						<span style="cursor: pointer; color: #999999" onclick="AdjustDateTime()">now</span>
					</td>
				</tr>
			</xsl:if>
			<tr>
				<td>
				</td>
				<td>
					<br /><br />
					<input type="submit" name="submit" id="SubmitButton" value="Add new article">
						<xsl:if test="starts-with (/page/manifest/uri/text(), '/adm/edit/') or starts-with (/page/manifest/uri/text(), '/adm/preview/')">
							<xsl:attribute name="value">Update this article</xsl:attribute>
						</xsl:if>
					</input>
				</td>
			</tr>
		</table>
	</form>
	<script type="text/javascript">
		TestEmptiness();
		function TestEmptiness()
		{
			var SubmitButton = document.getElementById ('SubmitButton');
			var TitleField = document.getElementById ('TitleField');
			var ContentField = document.getElementById ('ContentField');

			if (!SubmitButton || !TitleField || !ContentField) return;

			SubmitButton.disabled = !TitleField.value.length;
		}
	</script>
</xsl:template>

<xsl:template name="list-option">
	<xsl:param name="curr"/>
	<xsl:param name="sel"/>
	<xsl:param name="max"/>
	<xsl:param name="zero" select="'false'"/>

	<option value="{$curr}">
		<xsl:if test="$curr = $sel">
			<xsl:attribute name="selected">selected</xsl:attribute>
		</xsl:if>
		<xsl:if test="$curr &lt; 10">
			<xsl:choose>
				<xsl:when test="$zero = 'true'">0</xsl:when>
				<xsl:otherwise>&#160;&#160;</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
		<xsl:value-of select="$curr"/>
	</option>
	
	<xsl:if test="$curr != $max">
		<xsl:call-template name="list-option">
			<xsl:with-param name="curr" select="$curr + 1"/>
			<xsl:with-param name="sel" select="$sel"/>
			<xsl:with-param name="max" select="$max"/>
			<xsl:with-param name="zero" select="$zero"/>
		</xsl:call-template>
	</xsl:if>
</xsl:template>

<xsl:template name="month-option">
	<xsl:param name="curr"/>
	<xsl:param name="month"/>

	<option value="{$curr}">
		<xsl:if test="$curr = $month">
			<xsl:attribute name="selected">selected</xsl:attribute>
		</xsl:if>
		<xsl:if test="$curr &lt; 10">0</xsl:if>
		<xsl:value-of select="$curr"/>
		<xsl:text> — </xsl:text>
		<xsl:call-template name="month-name">
			<xsl:with-param name="month" select="$curr"/>
		</xsl:call-template>
	</option>
	
	<xsl:if test="$curr != 12">
		<xsl:call-template name="month-option">
			<xsl:with-param name="curr" select="$curr + 1"/>
			<xsl:with-param name="month" select="$month"/>
		</xsl:call-template>
	</xsl:if>
</xsl:template>

<xsl:template name="preview-message">
	<div class="message">
		<h1>
			<a href="/{title/@uri}/">
				<xsl:value-of select="title/text()" disable-output-escaping="yes"/>
			</a>
		</h1>
		<xsl:value-of select="content/text() | content/*" disable-output-escaping="yes"/>

		<xsl:choose>
			<xsl:when test="keywords/item">
				<p class="keywords">
					<xsl:for-each select="keywords/item">
						<xsl:value-of select="text()" disable-output-escaping="yes"/>
						<xsl:if test="position() != last()">
							<xsl:text>, </xsl:text>
						</xsl:if>
					</xsl:for-each>
					<xsl:text>&#160;&#8212; </xsl:text>
					<xsl:call-template name="message-date"/>
				</p>
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="message-date"/>
			</xsl:otherwise>
		</xsl:choose>
	</div>
</xsl:template>

<xsl:template name="message-date">
	<span class="date">
		<xsl:value-of select="title/@day"/>
		<xsl:text>&#160;</xsl:text>
		<xsl:call-template name="month-name">
			<xsl:with-param name="month" select="title/@month"/>
		</xsl:call-template>
		<xsl:text>&#160;</xsl:text>
		<xsl:value-of select="title/@year"/>
	</span>
</xsl:template>

<xsl:template match="content/editor-list">
	<form method="post">
		<table>
			<thead>
				<tr>
					<td>Login</td>
					<td>E-mail</td>
					<td>Real name</td>
					<td>Active</td>
				</tr>
			</thead>
			<tbody>
				<xsl:apply-templates select="item[@login != 'main']"/>
				<tr>
					<td colspan="3" style="padding-bottom: 0">New editor:</td>
				</tr>
				<tr>
					<td>
						<input type="text" name="login0" />
					</td>
					<td>
						<input type="text" name="email0" />
					</td>
					<td>
						<input type="text" size="50" name="name0" />
					</td>
					<td>
						<input type="checkbox" name="active0" value="on" checked="checked" />
					</td>
				</tr>
			</tbody>
		</table>

		<div>
			<input type="submit" name="submit" value="Update list" />
		</div>
	</form>	
</xsl:template>

<xsl:template match="content/editor-list/item">
	<tr>
		<td>
			<input type="text" name="login{position() + 1}" value="{@login}" />
		</td>
		<td>
			<input type="text" name="email{position() + 1}" value="{@email}" />
		</td>
		<td>
			<input type="text" size="50" name="name{position() + 1}" value="{text()}" />
		</td>
		<td>
			<input type="checkbox" name="active{position() + 1}" value="on">
				<xsl:if test="@active = 1">
					<xsl:attribute name="checked">checked</xsl:attribute>
				</xsl:if>
			</input>
		</td>
	</tr>
</xsl:template>

<xsl:template match="error">
	<div style="color: red">
		<xsl:text>Error: </xsl:text>
		<i>
			<xsl:apply-templates/>
		</i>
	</div>
</xsl:template>

</xsl:stylesheet>
