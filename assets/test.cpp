#include <iostream>
#include <unordered_map>
using namespace std;

int lengthOfLongestSubstring(string s)
{
    int sz = s.size();
    int res = 0;

    int left = 0, right = 0;
    unordered_map<char, int> wd;

    while (right < sz)
    {
        if (wd.find(s[right]) == wd.end())
        {
            wd[s[right]] = right;
            right++;
            res = max(res, right - left);
        }
        else
        {
            while (left < wd[s[right]] + 1)
            {
                wd.erase(s[left]);
                left++;
            }
        }
    }
    return res;
}

int main(){
    string s= "abcabcbb";
    int res= lengthOfLongestSubstring(s);
    cout << res << endl;
}