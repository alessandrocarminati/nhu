#include<stdio.h>
#define __USE_GNU
#include<signal.h>
#include<ucontext.h>

int main(int argc, char *argv[])
{

  struct sigaction action;
  action.sa_sigaction = SIG_IGN;
  action.sa_flags = 0;
  action.sa_restorer = NULL;

  sigaction(1,&action,NULL);


}
