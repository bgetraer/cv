-- Lua code for parsing cv data for lualatex
-- Included within cv_template.tex, or can be tested as standalone
--	USEAGE:
--		luatex cv_parser.lua     -- standalone, print to terminal
--		lualatex cv_template.tex -- compile to pdf
--	DETAILS
--		The main function, renderCV() calls functions which render each
--		section to be printed.
-- Adapted from https://github.com/akshaymehra/cvData/

-- Standalone terminal run (ignored when running inside lualatex)
local is_standalone = (tex == nil or tex.print == nil)
if (is_standalone and kpse) then
	kpse.set_program_name("luatex")
end

-- Dependencies
require("lualibs.lua")

-- Declare objects shared by all functions
local M = {}
local data = {}
local sections_by_id = {}
local debug = false

-- function to load data
function M.loadJSON(filename)
	local f = assert(io.open(filename, "r"))
	local s = f:read("*a")
	f:close()
	data = assert(utilities.json.tolua(s), "Failed to parse JSON: " .. tostring(filename))

	-- create lookup table
	if debug then print("-- Sections Found:") end
	for _, section in ipairs(data.sections) do
		sections_by_id[section.id] = section
		if debug then print(section.id) end
	end
end

-- helper functions
local function sprintRaw(val)
	tex.sprint("{")
	if val and val ~= "" then tex.sprint(tostring(val)) end
	tex.sprint("}")
end
local function sprintArg(val)
	tex.sprint("{")
	if type(val) == "table" then
		for i, line in ipairs(val) do
			if i > 1 then tex.sprint("\\\\") end
			tex.sprint(-2, tostring(line))
		end
	elseif type(val) == "string" or type(val) == "number" then
		tex.sprint(-2, tostring(val))
	end
	tex.sprint("}")
end

-- list: array of "Last, I." names. max: optional cutoff (nil = show everyone)
local function sprintAuthors(list, max)
	local parts  = data.bio.name:split(" ")
	local myName = parts[#parts] .. ", " .. parts[1]:sub(1, 1) .. "."
	local cut    = max and #list > max

	-- 1. pick the names to show
	local names = {}
	local meShown, meInList = false, false
	for i, a in ipairs(list) do
		if a == myName then meInList = true end
		if not cut or i <= max then
			names[#names + 1] = a
			if a == myName then meShown = true end
		end
	end

	local function printName(a)
		if a == myName then
			tex.sprint("\\textbf{"); tex.sprint(-2, a); tex.sprint("}")
		else
			tex.sprint(-2, a)
		end
	end

	-- 2. print them
	tex.sprint("{")
	for i, a in ipairs(names) do
		if i > 1 then
			if not cut and #names == 2 then tex.sprint(" and ")
			elseif not cut and i == #names then tex.sprint(", and ")
			else tex.sprint(", ") end
		end
		printName(a)
	end
	if cut then
		if meInList and not meShown then
			tex.sprint(", ..., ")
			printName(myName)
		end
		tex.sprint(", et al.")
	end
	tex.sprint("}")
end

-- section functions
function M.renderBio()
	local b = data.bio
	tex.sprint("\\cvbio")
	sprintArg(b.name)
	sprintArg(b.department)
	sprintArg(b.institution)
	sprintArg(b.address)
	sprintArg(b.email)
	sprintArg(b.website_link)
	sprintArg(b.website_text)
end

function M.renderSection(sectionID)
	-- lookup section by id
	local section = assert(sections_by_id[sectionID], "No section with id '" .. sectionID .. "' in the JSON")
	-- then print heading
	tex.sprint('\\headings')
	sprintArg(section.heading)	
	tex.print("")

	----------------------------------------------------------------
	-- Education 
	----------------------------------------------------------------
	if section.id=='education' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for i, item in ipairs(section.data) do
			tex.sprint('\\education')
			sprintArg(item.date)
			sprintArg(item.institution)
			sprintArg(item.location)
			sprintArg(item.degree)
			sprintArg(item.thesis)
			sprintArg(item.advisor)
			tex.print("")
		end
		tex.print('\\end{tabularx}')	

	----------------------------------------------------------------
	-- Professional experience
	----------------------------------------------------------------
	elseif section.id == 'professional' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\professional')
			sprintArg(c.role)
			sprintArg(c.institution)
			tex.print('')
			for _, p in ipairs(c.periods) do
				tex.sprint('\\stint')
				sprintArg(p.date)
				sprintArg(p.location)
				sprintArg(p.description)
				tex.print('')
			end
		end
		tex.print('\\end{tabularx}')
	
	----------------------------------------------------------------
	-- Publications
	----------------------------------------------------------------
	elseif section.id == 'publications' then
		local order = {'in preparation', 'in submission', 'in review', 'published or in press'}
		local count = #section.data   -- numbers count down from the total

		-- loop through the publication state
		for _, state in ipairs(order) do
			local group = {}
			for _, p in ipairs(section.data) do
				if p.state == state then group[#group + 1] = p end
			end

			if #group > 0 then
				tex.sprint('\\subheadings')
				sprintArg(state:sub(1,1):upper() .. state:sub(2))
				tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
				for _, p in ipairs(group) do
					tex.sprint('\\publication')
					sprintArg(count .. '.')
					sprintAuthors(p.authors, 6)
					sprintArg(p.year)
					sprintRaw(p.title)
					sprintArg(p.journal)
					tex.sprint('{'); tex.sprint(-2, p.link or ''); tex.sprint('}')  -- URL stays literal
					sprintArg(p.linkText)
					sprintArg(p.note)
					tex.print('')
					count = count - 1
				end
			end
			tex.print('\\end{tabularx}')
		end

		----------------------------------------------------------------
		-- Conferences
		------------------------------------------------------------------
	elseif section.id == 'conferences' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\conference')
			sprintArg(c.month)
			sprintArg(c.year)
			sprintAuthors(c.authors,6)
			sprintRaw(c.title)
			sprintArg(c.type)
			sprintArg(c.conference_name)
			sprintArg(c.location)
			tex.print('')
		end
		tex.print('\\end{tabularx}')

		----------------------------------------------------------------
		-- Invited talks
		------------------------------------------------------------------
	elseif section.id == 'invited' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\invitedtalk')
			sprintArg(c.month)
			sprintArg(c.year)
			sprintRaw(c.title)
			sprintArg(c.event)
			sprintArg(c.location)
			tex.print('')
		end
		tex.print('\\end{tabularx}')

		----------------------------------------------------------------
		-- Teaching
		------------------------------------------------------------------
	elseif section.id == 'teaching' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\course')
			sprintArg(c.date)
			sprintArg(c.course_number)
			sprintArg(c.school)
			sprintArg(c.course_title)
			sprintArg(c.role)
			sprintArg(c.description)
			tex.print('')
		end
		tex.print('\\end{tabularx}')

		----------------------------------------------------------------
		-- Field Experience
		------------------------------------------------------------------
	elseif section.id == 'fieldwork' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\fieldwork')
			sprintArg(c.date)
			sprintArg(c.location)
			sprintArg(c.length)
			sprintArg(c.description)
			tex.print('')
		end
		tex.print('\\end{tabularx}')
		----------------------------------------------------------------
		-- Professional Activities
		------------------------------------------------------------------
	elseif section.id == 'professionalActivities' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\professionalactivity')
			sprintArg(c.role)
			sprintArg(c.description)
			tex.print('')
		end
		tex.print('\\end{tabularx}')
		----------------------------------------------------------------
		-- University and Professional Service
		------------------------------------------------------------------
	elseif section.id == 'service' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\service')
			sprintArg(c.date)
			sprintArg(c.role)
			sprintArg(c.organization)
			tex.print('')
		end
		tex.print('\\end{tabularx}')
		----------------------------------------------------------------
		-- Awards
		------------------------------------------------------------------
	elseif section.id == 'awards' then
		tex.print('\\begin{tabularx}{\\textwidth}{@{}D X@{}}')
		for _, c in ipairs(section.data) do
			tex.sprint('\\award')
			sprintArg(c.date)
			sprintArg(c.description)
			tex.print('')
		end
		tex.print('\\end{tabularx}')
	end
end

if is_standalone then
	tex = {
		sprint = function(catcode, ...)
			if type(catcode) == "number" then
				io.write(...)
			else
				io.write(catcode, ...)
			end
		end,
		print = function(catcode, ...)
			if type(catcode) == "number" then
				print(...)
			else
				print(catcode, ...)
			end
		end
	}
	debug=true
	print('Running standalone CV parser and printing to command line:')
	print('----------------------------------------------------------')
	print('-- Calling M.loadJSON(arg[1])')
	print('')
	M.loadJSON(arg[1])
	print('')
	print('-- Calling M.renderBio()')
	M.renderBio()
	print('')
	print('')
	print('-- Calling M.renderSection(\'education\')')
	M.renderSection('education')
	print('')
	print('-- Calling M.renderSection(\'professional\')')
	M.renderSection('professional')
	print('')
	print('-- Calling M.renderSection(\'publications\')')
	M.renderSection('publications')
	print('')
	print('-- Calling M.renderSection(\'conferences\')')
	M.renderSection('conferences')
	print('')
	print('-- Calling M.renderSection(\'invited\')')
	M.renderSection('invited')
	print('')
	print('-- Calling M.renderSection(\'teaching\')')
	M.renderSection('teaching')
	print('')
	print('-- Calling M.renderSection(\'fieldwork\')')
	M.renderSection('fieldwork')
	print('')
	print('-- Calling M.renderSection(\'professionalActivities\')')
	M.renderSection('professionalActivities')
	print('')
	print('-- Calling M.renderSection(\'service\')')
	M.renderSection('service')
	print('')
	print('-- Calling M.renderSection(\'awards\')')
	M.renderSection('awards')
end
-- return M object
return M
