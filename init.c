/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   init.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: kiroussa <oss@xtrm.me>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2025/02/10 23:57:36 by kiroussa          #+#    #+#             */
/*   Updated: 2025/02/11 05:33:05 by kiroussa         ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include <signal.h>
#include <stdio.h>

static void	signal_handler(int sig)
{
	(void)sig;
	printf("init.c: signal_handler(%d)\n", sig);
}

int	main(int argc, char **argv)
{
	int	i;

	i = 0;
	while (++i < argc)
		printf("argv[%d] = %s\n", i, argv[i]);
	i = -1;
	while (++i < NSIG)
		signal(i, signal_handler);
	printf("init.c: hello userspace\n");
	while (1)
		;
	return (0);
}
