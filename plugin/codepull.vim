if !has('python')
	finish
endif

command! -nargs=1 Pull call PullCode(<f-args>)
function! PullCode(description)


python <<_EOF_

#import csv
import os
import collections
from HTMLParser import HTMLParser
import re
import urllib
import urllib2
import requests
import vim
from collections import namedtuple, Counter

Line = namedtuple('Line', 'line code')


class CodeRetriever:
	unwanted = 'string', 'int', 'double', 'float', 'bool', 'boolean', 'char', 'integer'


	#initialize the class with keywords and language
	def __init__(self, keywords, lang):
		self.keywords = [w.lower() for w in keywords if w.lower() not in self.unwanted]
		d = {'javascript': '22',
			'swift':137,
			'python':19,
			'c': 28,
			'java':23,
			'php':24,
			'cpp':16,
			'lisp':29,
			'html':3,
			'header':15,
			'ruby':32,
			'perl':51,
			'vimscript':33,
			'haskell':40,
			'scala':47,
			'markdown':118,
			'pascal':46,
			'erlang':25,
			'actionscript':42,
			'lua':54,
			'go':55,
			'objective-c':21,
			'json':122,
			'd':45,
			'config':113,
			'ocaml':64,
			'coffeescript':106,
			'matlab':20,
			'assembly':34,
			'typescript':151}
		l = d[lang]
		self.language = int(l)#this will be determined from the ending of the file
		#print self.language

	def removeCommentOnlyCode(self, lineGroups):
		allComment = []
		def isComment(code):
			return code.startswith('#') or code.startswith('//') or code.startswith('\'') or code.startswith('"')
		return [group for group in lineGroups if not all(isComment(line.code) for line in group)]


	#get the groupings of lines that are returned
	def pickMostLikelyCode(self, lineSegments):
		#here we look for code that:
		#a) does shit(we don't want method declarations and all that shit, we want code)
		#b) seems to do the right thing (methods that are named similar to keywords)
		#TODO: implement an algorithm that finds other ways to predict if code does the right thing
		codeGroups = []
		codeLine =''

		#list of general programming terms we don't want included
		#delete all general terms from the keywords

		#compile the lines into code segments
		for segment in lineSegments:
			code = '\n'.join(line.code for line in segment)
			codeGroups.append(code)


		def keywordEstimator(segment):
			words = Counter(segment)
			hits = 0
			for keyword in self.keywords:
				hits += sum(v for k, v in words.items() if keyword in k)
			return hits


		wantedCode = max(codeGroups, key=keywordEstimator)
		return wantedCode

	#scrape and grab code from github
	def querySearchCode(self):
		params = '+'.join(self.keywords)
		url = 'https://searchcode.com/api/codesearch_I/'#?q=reverse+string&lan=19'
		q = {'q':params,
			'lan':self.language}#for testing purposes, make this python. Will add a dict later that has language to number mappings
		#request the data from the page, and then we will pull the code out? or open the file to the location and pull out from start to end braces/ indent?
		page = requests.get(url, params=q)
		js = page.json()
		firstCodeSet = js['results'][0]['lines']
		lineGroups = self.getLineGroups(firstCodeSet)
		lineGroups = self.removeCommentOnlyCode(lineGroups)
		#extract section of html containing top answer
		finCode = self.pickMostLikelyCode(lineGroups)
		return finCode
		#if we did, follow the link to the code, and extract the entire method that is there


	def getLineGroups(self, lineDict):
		lines = sorted((Line(l, c) for l, c in lineDict.items()), reverse=True)
		groupNumber = 0
		finGroups = []
		segment = []
		#until the list is empty
		while lines:
			line = lines.pop()
			#if this is the first line ever, just put it in
			if not segment:
				segment.append(line)
			else:
				#if the line is 1 greater than the max in the list, it is the next line, so append it
				if line.line == int(max(segment).line)+1:
					segment.append(line)
				#else, it belongs in a new group, so finalize the old group, and start a new one
				else:
					finGroups.append(segment)
					groupNumber = groupNumber + 1
					segment = []
					segment.append(line)
		finGroups.append(segment)
		return finGroups


args = vim.eval("a:description")

argsDict = args.split(' ')

vim.command("let r = &filetype")


ftype = vim.eval("r")


cr = CodeRetriever(argsDict, ftype)

fin = cr.querySearchCode()

codeArr = fin.split('\n')
vim.command("let ret = \"%s\"" %fin)

_EOF_


let codeArr = split(ret, "\n")
let codeArrReverse = reverse(codeArr)
for i in codeArrReverse
	call append('.', i)
endfor

endfunction
