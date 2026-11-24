-- Builds an HTML CV fragment from cv_data.json
--	Output is one <div class="cv">...</div>, meant to be inserted into the
--	body of your own page template. All styling is scoped to .cv (see cv.css).
--	USAGE:
--		texlua cv_html.lua cv_data.json > cv_fragment.html
--	Uses the same JSON as the LaTeX build.

kpse.set_program_name("luatex")
require("lualibs.lua")

----------------------------------------------------------------
-- Load data
----------------------------------------------------------------
local f = assert(io.open(arg[1] or "cv_data.json", "r"))
local data = assert(utilities.json.tolua(f:read("*a")), "Failed to parse JSON")
f:close()

local out = {}
local function add(s) out[#out + 1] = s end

local pdf_file = "cv_bgetraer.pdf"

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function has(v) return v ~= nil and v ~= "" end

-- escape characters that mean something in HTML
local function esc(s)
	s = tostring(s)
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
	return s
end

-- JSON text -> HTML text
--   \% and \& -> % and &    (from LaTeX-style escapes in titles)
--   --        -> en dash
--   ~         -> non-breaking space
--   $x$       -> <i>x</i>   (simple math; use MathJax if you need real math)
local function text(s)
	if not has(s) then return "" end
	s = tostring(s)
	s = s:gsub("\\%%", "%%"):gsub("\\&", "&")
	s = esc(s)
	s = s:gsub("%-%-", "–"):gsub("~", "&nbsp;")
	s = s:gsub("%$(.-)%$", "<var>%1</var>")
	return s
end

local function link(url, label)
	return '<a href="' .. esc(url) .. '">' .. text(label) .. '</a>'
end

-- join the non-empty values, each on its own line
local function lines(...)
	local t = {}
	for n = 1, select("#", ...) do
		local v = select(n, ...)
		if has(v) then t[#t + 1] = "<div>" .. v .. "</div>" end
	end
	return table.concat(t)
end


-- author list with my name in bold (e.g. "Getraer, B.")
local parts = data.bio.name:split(" ")
local myName = parts[#parts] .. ", " .. parts[1]:sub(1, 1) .. "."
-- list: array of "Last, I." names. max: optional cutoff (nil = show everyone)
local function authors(list)
	local names = {}
	local meShown, meInList = false, false
	for i, a in ipairs(list) do
		if a == myName then meInList = true end
		if not cut or i <= max then
			names[#names + 1] = a
			if a == myName then meShown = true end
		end
	end

	local function name(a)
		if a == myName then return "<strong>" .. text(a) .. "</strong>" end
		return text(a)
	end

	local s = ""
	for i, a in ipairs(names) do
		if i > 1 then
			if #names == 2 then s = s .. " and "
			elseif i == #names then s = s .. ", and "
			else s = s .. ", " end
		end
		s = s .. name(a)
	end
	return s
end

----------------------------------------------------------------
-- Table
----------------------------------------------------------------
local function open_table()
	add('<table class="cv-table" style="width:100%;table-layout:fixed">')
	add('<colgroup><col style="width:25%"><col style="width:75%"></colgroup>')
end
local function row(left, right)
	add('<tr><td class="cv-date" style="width:25%;text-align:left;vertical-align:top">' .. text(left) .. '</td><td class="cv-item" style="vertical-align:top">' .. right .. '</td></tr>')
end

----------------------------------------------------------------
-- Page header
----------------------------------------------------------------
local b = data.bio
-- add('<header class="cv-header">')
-- add('<div class="cv-name">' .. text(b.name) .. '</div>')
-- add('<p>' .. text(b.department) .. ' | ' .. text(b.institution) .. '<br>'
-- 	.. text(b.address) .. '<br>'
-- 	.. '<a href="mailto:' .. esc(b.email) .. '">' .. text(b.email) .. '</a> | '
-- 	.. link(b.website_link, b.website_text) .. '</p>')
-- add('</header>')

add('<section>' .. 
 	'<h2>Curriculum Vitae</h2>' ..
 	'<p>A .PDF version can be viewed <a href="cv_bgetraer.pdf">here</a>.</p>' ..
 	'</section>')

add('<div class="cv">')

----------------------------------------------------------------
-- Sections, in the order they appear in the JSON
----------------------------------------------------------------
for _, sec in ipairs(data.sections) do
	add('<section id="' .. esc(sec.id) .. '">')
	add('<h2>' .. text(sec.heading) .. '</h2>')
	local uses_table = (sec.id ~= 'publications')
	if uses_table then open_table() end

	----------------------------------------------------------------
	-- Education
	----------------------------------------------------------------
	if sec.id == 'education' then
		for _, c in ipairs(sec.data) do
			row(c.date, lines(
				text(c.institution) .. ", " .. text(c.location),
				text(c.degree),
				has(c.thesis) and ("Thesis: " .. text(c.thesis)) or nil,
				"Advisor(s): " .. text(c.advisor)))
		end

	----------------------------------------------------------------
	-- Professional experience
	----------------------------------------------------------------
	elseif sec.id == 'professional' then
		for _, c in ipairs(sec.data) do
			row("", "<strong>" .. text(c.role) .. "</strong>, " .. text(c.institution))
			for _, p in ipairs(c.periods) do
				row(p.date, text(p.location))
				if has(p.description) then
					row("", '<span class="cv-desc">' .. text(p.description) .. '</span>')
				end
			end
		end

	----------------------------------------------------------------
	-- Publications: grouped by status, numbered downward
	----------------------------------------------------------------
	elseif sec.id == 'publications' then
	local order = {'in preparation', 'in submission', 'in review', 'published or in press'}
	local count = #sec.data

	for _, state in ipairs(order) do
		local group = {}
		for _, p in ipairs(sec.data) do
			if p.state == state then group[#group + 1] = p end
		end

		if #group > 0 then
			add('<h3>' .. text(state:sub(1, 1):upper() .. state:sub(2)) .. '</h3>')
			open_table()
			for _, p in ipairs(group) do
				local s = authors(p.authors)
				s = s .. " (" .. text(p.year) .. ")."
				s = s .. " " .. text(p.title) .. "."
				if has(p.journal) then
					s = s .. " <i>" .. text(p.journal) .. "</i>"
				end
				if has(p.link) then
					s = s .. (has(p.journal) and ", " or " ") .. link(p.link, p.linkText)
				end
				if has(p.journal) or has(p.link) then s = s .. "." end
				if has(p.note) then
					s = s .. '<div class="cv-note">' .. text(p.note) .. '</div>'
				end

				row(count .. ".", s)      -- number goes in the first column
				count = count - 1
			end
			add('</table>')
		end
	end
	----------------------------------------------------------------
	-- Conferences
	----------------------------------------------------------------
	elseif sec.id == 'conferences' then
		for _, c in ipairs(sec.data) do
			row(c.month .. " " .. c.year,
				authors(c.authors) .. " <i>" .. text(c.title) .. "</i> [" .. text(c.type) .. "]. "
				.. text(c.conference_name) .. ", " .. text(c.location) .. ".")
		end

	----------------------------------------------------------------
	-- Invited talks
	----------------------------------------------------------------
	elseif sec.id == 'invited' then
		for _, c in ipairs(sec.data) do
			row(c.month .. " " .. c.year,
				"<i>" .. text(c.title) .. "</i>, " .. text(c.event) .. ", " .. text(c.location) .. ".")
		end

	----------------------------------------------------------------
	-- Teaching
	----------------------------------------------------------------
	elseif sec.id == 'teaching' then
		for _, c in ipairs(sec.data) do
			row(c.date, lines(
				"<strong>" .. text(c.course_number) .. "</strong>: " .. text(c.course_title)
					.. " (" .. text(c.role) .. ", " .. text(c.school) .. ")",
				has(c.description) and ('<span class="cv-desc">' .. text(c.description) .. '</span>') or nil))
		end

	----------------------------------------------------------------
	-- Field experience
	----------------------------------------------------------------
	elseif sec.id == 'fieldwork' then
		for _, c in ipairs(sec.data) do
			row(c.date, lines(
				text(c.location) .. " [" .. text(c.length) .. "]",
				has(c.description) and ('<span class="cv-desc">' .. text(c.description) .. '</span>') or nil))
		end

	----------------------------------------------------------------
	-- Professional activities (role in the left column)
	----------------------------------------------------------------
	elseif sec.id == 'professionalActivities' then
		for _, c in ipairs(sec.data) do
			row(c.role, text(c.description))
		end

	----------------------------------------------------------------
	-- Service
	----------------------------------------------------------------
	elseif sec.id == 'service' then
		for _, c in ipairs(sec.data) do
			row(c.date, text(c.role) .. ", " .. text(c.organization))
		end

	----------------------------------------------------------------
	-- Awards
	----------------------------------------------------------------
	elseif sec.id == 'awards' then
		for _, c in ipairs(sec.data) do
			row(c.date, text(c.description))
		end

	else
		io.stderr:write("No HTML layout for section '" .. tostring(sec.id) .. "', skipped\n")
	end

	if uses_table then add('</table>') end
	add('</section>')
end

add('</div>')

io.write(table.concat(out, "\n"), "\n")
