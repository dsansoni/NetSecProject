#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

/*char *randomCharArray(char *strMaxNumber);
char *getStrNumberWithoutLeadingZeros(char *strNumber);
int getLastLeadingZeroPosition(char *strNumber);

int main(int argc, char *argv[])
{
char bignum[] = "123987534756338913891081309014";
char *randomBignum=NULL;   //+1 for '\0'

    srand(time(NULL));
    
    randomBignum=randomCharArray(bignum);
    
    printf("BIGNUM:               %s\n",bignum);
    printf("RANDOM BIGNUM:        %s\n",randomBignum);
    printf("PURGED RANDOM BIGNUM: %s\n",getStrNumberWithoutLeadingZeros(randomBignum));
    
    return 0;
}*/



char *randomCharArray(char *strMaxNumber)
{
    int randomCharArrayLength = (rand()%strlen(strMaxNumber))+2; //+2 = +1 (to get length 1..strlen(s)) + 1(for '\0')
    // 1 means that both s and r have same digit in the same position (starting from left).
    // This means we cannot generate random digit from 0 to 9, we have to generate from 0 to s[i]
    int critical = (randomCharArrayLength==strlen(strMaxNumber))?1:0;  //If same lenght, then there's of course critical on first digit (from left)
    
    //String that contains randomNumber generated
    char *r = malloc(randomCharArrayLength * (sizeof(char)));
    
    printf("\n----------- [DEBUG] randomCharArray() ----------\n");
    printf("\tLength s:  %lu\n",strlen(strMaxNumber));
    printf("\tLength r:  %d\n",randomCharArrayLength-1);
    printf("\tCritical:  %d\n",critical);
    
    int i;
    //for (int i = 0; i < strlen(strMaxNumber); i++)
    for (i = 0; i < randomCharArrayLength-1; i++)
    {
        int lm = strMaxNumber[i] - '0';
        if (critical)
        {
            r[i] = (rand()%(lm+1)) + '0';
            critical = (r[i] == strMaxNumber[i]) ? 1 : 0;
        }
        else
        {
            r[i] = (rand()%10) + '0';
        }
    }
    r[randomCharArrayLength-1] = '\0';
    
    printf("\tRandom Number: %s\n",r);
    printf("---------------------------------------------------\n\n");
    
    if(atoi(r)==0)  //If we get 0 as random number we try again
    {
        printf("[ATTENTION] Random generated number is zero -> Computing Again!\n");
        free(r);    //The number we generated is useless since it is 0, so we delete the memory allocated
        return randomCharArray(strMaxNumber);
    }
    
    return r;
}

char *getStrNumberWithoutLeadingZeros(char *strNumber)
{
    int posOfLastLeadingZero = getLastLeadingZeroPosition(strNumber);
    int lengthPurgedString = (strlen(strNumber)-posOfLastLeadingZero);
    char *purgedString;
    int i;
    
    if(posOfLastLeadingZero == -1) //It means that the first char of strNumber is !=0 -> no leading zero to remove
        return strNumber;
    
    purgedString = malloc(lengthPurgedString * (sizeof(char)));
    
    for(i=0;i<lengthPurgedString-1;i++)
        purgedString[i]=strNumber[i+posOfLastLeadingZero+1];
    
    printf("\n---- [DEBUG] getStrNumberWithoutLeadingZeros() ----\n");
    printf("\tLength STR Random Bignum (NOT PURGED): %lu\n",strlen(strNumber));
    printf("\tLast Leading Zero Position: %d\n",posOfLastLeadingZero);
    printf("\tLength of Purged String: %d\n",lengthPurgedString);
    printf("---------------------------------------------------\n\n");
    
    
    //purgedString[lengthPurgedString]='\0';
    return purgedString;
}

int getLastLeadingZeroPosition(char *strNumber)
{
int posFound = -1;
int i=0;
    
    if(strNumber[0]!='0')   //If first digit is not zero, it means there's no leading zeros to remove
        return posFound;
    else posFound = 0;
    
    for(i=1;i<strlen(strNumber);i++)
    {
        if(strNumber[i]=='0' && strNumber[i-1]=='0')
            posFound=i;
        else
            return posFound;
    }
    
    //Should not exit here!
    return posFound;
}
