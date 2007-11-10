/*
  regcomp.c - TRE POSIX compatible regex compilation functions.

  Copyright (C) 2001-2004 Ville Laurikari <vl@iki.fi>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 (June
  1991) as published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*/

#include "flx_target_tre_config.hpp"

#include <string.h>
#include <errno.h>
#include <stdlib.h>

#include "tre_regex.hpp"
#include "tre_internal.hpp"
#include "tre_xmalloc.hpp"

int
regncomp(regex_t *preg, const char *regex, size_t n, int cflags)
{
  int ret;
#if TRE_WCHAR
  tre_char_t *wregex;
  int wlen;

  wregex = (tre_char_t*)xmalloc(sizeof(tre_char_t) * (n + 1));
  if (wregex == NULL)
    return REG_ESPACE;

  /* If the current locale uses the standard single byte encoding of
     characters, we don't do a multibyte string conversion.  If we did,
     many applications which use the default locale would break since
     the default "C" locale uses the 7-bit ASCII character set, and
     all characters with the eighth bit set would be considered invalid. */
#if TRE_MULTIBYTE
  if (TRE_MB_CUR_MAX == 1)
#endif /* TRE_MULTIBYTE */
    {
      unsigned int i;
      const unsigned char *str = (unsigned char *)regex;
      tre_char_t *wstr = wregex;

      for (i = 0; i < n; i++)
        *(wstr++) = *(str++);
      wlen = n;
    }
#if TRE_MULTIBYTE
  else
    {
      int consumed;
      tre_char_t *wcptr = wregex;
#ifdef HAVE_MBSTATE_T
      mbstate_t state;
      memset(&state, '\0', sizeof(state));
#endif /* HAVE_MBSTATE_T */
      while (n > 0)
        {
          consumed = tre_mbrtowc(wcptr, regex, n, &state);

          switch (consumed)
            {
            case 0:
              if (*regex == '\0')
                consumed = 1;
              else
                {
                  xfree(wregex);
                  return REG_BADPAT;
                }
              break;
            case -1:
              DPRINT(("mbrtowc: error %d: %s.\n", errno, strerror(errno)));
              xfree(wregex);
              return REG_BADPAT;
            case -2:
              /* The last character wasn't complete.  Let's not call it a
                 fatal error. */
              consumed = n;
              break;
            }
          regex += consumed;
          n -= consumed;
          wcptr++;
        }
      wlen = wcptr - wregex;
    }
#endif /* TRE_MULTIBYTE */

  wregex[wlen] = L'\0';
  ret = tre_compile(preg, wregex, wlen, cflags);
  xfree(wregex);
#else /* !TRE_WCHAR */
  ret = tre_compile(preg, (const tre_char_t*)regex, n, cflags);
#endif /* !TRE_WCHAR */

  return ret;
}

int
regcomp(regex_t *preg, const char *regex, int cflags)
{
  return regncomp(preg, regex, regex ? strlen(regex) : 0, cflags);
}


#ifdef TRE_WCHAR
int
regwncomp(regex_t *preg, const wchar_t *regex, size_t n, int cflags)
{
  return tre_compile(preg, regex, n, cflags);
}

int
regwcomp(regex_t *preg, const wchar_t *regex, int cflags)
{
  return tre_compile(preg, regex, regex ? wcslen(regex) : 0, cflags);
}
#endif /* TRE_WCHAR */

void
regfree(regex_t *preg)
{
  tre_free(preg);
}

/* EOF */
